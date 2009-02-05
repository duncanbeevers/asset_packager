require 'tsort'
require 'tempfile'

class AssetPackager
  attr_reader :target
  
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
  
  def initialize options = {}
    @target = options[:target]
    @includes = Array(options[:includes])
    @excludes = Array(options[:excludes]) + [target||'']
    @dependencies = options.fetch(:dependencies, {})
  end
  
  # def to_s
  #   package! if dirty?
  #   File.read(target)
  # end
  
  def dirty?
    !FileUtils.uptodate?(target, contents)
  end
  
  def includes
    Dir[*@includes]
  end
  
  def excludes
    Dir[*@excludes]
  end
  
  def contents
    (Dep.from_array(includes - excludes) + @dependencies).tsort
  end
  
  def compressor
    File.expand_path(File.join(File.dirname(__FILE__), '../vendor/yuicompressor-2.4.2.jar'))
  end
  
  def package!
    Tempfile.open('buffer') do |buffer|
      contents.each { |filename| `cat #{filename} >> #{buffer.path}; echo ';' >> #{buffer.path}` }
      `java -jar #{compressor} --type #{type} -o #{target} #{buffer.path}`
    end
  end
  
  def type
    raise NotImplementedError, "type must be implemented by a child class"
  end
  
  def self.from_manifest path
    new(parse_manifest(path))
  end
  
  def self.parse_manifest path
    yaml = YAML.load_file(path).symbolize_keys
    prefix = yaml.fetch(:prefix, '')
    target = File.join(prefix, yaml[:target]) or raise ArgumentError, "No target defined."
    add_prefix = lambda { |path| File.join(prefix, path) }
    {
      :target => target,
      :includes => yaml.fetch(:includes,[]).map(&add_prefix),
      :excludes => yaml.fetch(:excludes,[]).map(&add_prefix),
      :dependencies => yaml.fetch(:dependencies, {}).inject({}) do |m,(k,v)|
                         m.merge add_prefix[k] => (v || []).map(&add_prefix)
                       end
    }
  end
end
