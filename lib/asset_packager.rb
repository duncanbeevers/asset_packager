require 'tsort'
require 'tempfile'
require 'base64'
require 'digest/md5'
  

class AssetPackager
  require 'sheller'
  
  # Dependency graph
  class Dep < Hash
    include TSort
    alias tsort_each_node each_key
    
    def tsort_each_child(node, &block)
      fetch(node, []).each(&block)
    end
    
    def self.from_array(array)
      array.inject(Dep.empty) { |d,e| d.merge(e => []) }
    end
    
    def self.empty
      new()
    end
    
    def +(dep)
      merge(dep) { |e, d0, d1| d0 | d1 }
    end
  end
  
  def initialize(options = {})
    @prefix = options[:prefix]
    @inline = options[:inline]
    @includes = []
    @excludes = []
    @dependencies = {}
    @target = options[:target]

    _add_includes(options[:includes])
    _add_excludes(options[:excludes])
    _add_dependencies(options[:dependencies])
    _compute_expanded_implicit_includes_and_excludes
  end
  
  def inline?
    @inline
  end
  
  def unpackaged_body
    @unpackaged_body ||= contents.map do |file|
      File.read(file)
    end.join
  end
  
  def packaged_body
    return @packaged_body if @packaged_body
    
    package! if dirty?
    @packaged_body = File.read(target)
  end
  
  def target(options = {})
    @target && options[:target_path] ?
      File.join(options[:target_path] , prefix_path(@target)) : prefix_path(@target)
  end

  def targets(options = {})
    [ target(options) ]
  end
  
  def dirty?
    target && !FileUtils.uptodate?(target, contents)
  end
  
  def contents(options = {})
    (
      (
        (Dep.from_array(@explicit_includes) + @dependencies).tsort + 
        @implicit_includes.sort
      )
    ).compact.uniq
  end
  
  def package!(options = {})
    raise NoTargetSpecifiedError unless target
  end
  
  def add_includes(c)
    _add_includes(c)
    _compute_expanded_implicit_includes_and_excludes
    self
  end

  def add_excludes(c)
    _add_excludes(c)
    _compute_expanded_implicit_includes_and_excludes
    self
  end

  def add_dependencies(c)
    _add_dependencies(c)
    _compute_expanded_implicit_includes_and_excludes
    self
  end

  def id
    self.class.digest(id_seed)
  end

  private
  def files_at_path(d)
    Dir[prefix_path(d)]
  end

  def _add_includes(c)
    @includes = (Array(c).map { |f| files_at_path(f) }.flatten + @includes).sort
  end

  def _add_excludes(c)
    @excludes = (Array(c).map { |f| files_at_path(f) }.flatten + @excludes)
  end

  def _add_dependencies(c)
    @dependencies = (c || {}).inject(@dependencies) do |m,(k,v)|
      dep = files_at_path(k)
      raise ArgumentError if dep.length > 1
      dep.length > 0 ?
        m.merge(dep[0] => Array(v).map { |f| files_at_path(f) }.flatten) : m
    end
  end

  def _compute_expanded_implicit_includes_and_excludes
    closure = @dependencies.to_a.flatten.map { |f| files_at_path(f) }.flatten # transitive closure of dependency graph
    @explicit_includes, @implicit_includes = (@includes - @excludes).partition do |filename|
      closure.include?(filename)
    end
  end

  def self.from_manifest(path)
    instance = new(parse_manifest(path))
    AssetPackager.instances_from_manifests << instance
    instance
  end

  def self.digest(string)
    Base64.urlsafe_encode64(Digest::MD5.digest(string)).gsub(/=*$/, '')
  end

  def self.instances_from_manifests
    @instances_from_manifests ||= []
  end
  
  def self.vendor_jar(jar_name)
    File.expand_path(File.join(File.dirname(__FILE__), ('../vendor/%s.jar' % jar_name)))
  end
  
  private
  def self.parse_manifest(manifest_path)
    yaml_hash    = YAML.load_file(manifest_path)
    raise ArgumentError, "#{path} should contain a YAML hash" unless yaml_hash.is_a?(Hash)
    yaml = yaml_hash.inject({}) { |a, (k, v)| a[k.to_sym] = v; a }
    raise NoTargetSpecified, "No target defined." unless yaml[:target]
    
    yaml.merge(
      :target        => yaml[:target],
      :includes      => Array(yaml[:includes]),
      :excludes      => Array(yaml[:excludes]),
      :dependencies  => yaml[:dependencies]
    )
  end

  protected
  def prefix_path(*parts)
    return nil unless parts[0]

    resolved_parts = parts.map { |p| p.respond_to?(:call) ? p.call(self) : p }
    resolved_parts.unshift(@prefix) if @prefix
    File.join(*resolved_parts)
  end

  def id_seed
    contents.join
  end
  
  class NoTargetSpecifiedError < StandardError
  end
end
