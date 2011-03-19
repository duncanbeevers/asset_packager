require File.join(File.dirname(__FILE__), 'test_helper')

class CustomPackager < AssetPackager
  attr_reader :initialization_options
  def initialize(options = {})
    @initialization_options = options
    super
  end
end

class AssetPackagerTest < Test::Unit::TestCase
  def test_includes
    p = AssetPackager.new(:includes => 'test/fixtures/*.js')
    assert_same_elements Dir['test/fixtures/*.js'], p.contents
  end
  
  def test_multiple_includes
    p = AssetPackager.new(:includes => ['test/fixtures/a.js', 'test/fixtures/b.js'])
    assert_same_elements Dir['test/fixtures/{a,b}.js'], p.contents
  end
  
  def test_add_includes
    p = AssetPackager.new(:includes => ['test/fixtures/a.js'])
    assert_equal p, p.add_includes(['test/fixtures/b.js']),
      "Expected adding includes to return the package instance for chaining"
    assert_same_elements Dir['test/fixtures/{a,b}.js'], p.contents
  end

  def test_excludes
    p = AssetPackager.new(
      :includes => 'test/fixtures/*.js',
      :excludes => 'test/fixtures/b.js'
    )
    assert_same_elements Dir['test/fixtures/*[^b].js'], p.contents
  end
  
  def test_add_excludes
    p = AssetPackager.new(:includes => [ 'test/fixtures/a.js', 'test/fixtures/b.js' ])
    assert_equal p, p.add_excludes('test/fixtures/b.js'),
      "Expected adding excludes rules to return the package instance for chaining"
    assert_same_elements([ 'test/fixtures/a.js' ], p.contents)
  end
  
  def test_dependency
    p = AssetPackager.new(
      :includes     => 'test/fixtures/*.js',
      :dependencies => {
        'test/fixtures/a.js' => [ 'test/fixtures/b.js' ]
      }
    )
    
    assert_precedes 'test/fixtures/b.js', 'test/fixtures/a.js', p.contents
  end

  def test_single_dependency_string
    p = AssetPackager.new(
      :includes => [ 'test/fixtures/a.js', 'test/fixtures/b.js' ],
      :dependencies => { 'test/fixtures/a.js' => 'test/fixtures/b.js' }
    )

    assert_precedes 'test/fixtures/b.js', 'test/fixtures/a.js', p.contents
  end

  def test_add_dependencies
    p = AssetPackager.new(:includes => [ 'test/fixtures/a.js', 'test/fixtures/b.js' ])
    assert_equal p, p.add_dependencies('test/fixtures/a.js' => [ 'test/fixtures/b.js' ]),
      "Expected adding dependencies to return the package instance for chaining"
    assert_precedes 'test/fixtures/b.js', 'test/fixtures/a.js', p.contents
  end
  
  def test_target
    p = AssetPackager.new(:target => 'test/tmp/all.js')
    assert_equal 'test/tmp/all.js', p.target
  end

  def test_targets
    p = AssetPackager.new(:target => 'test/tmp/all.js')
    assert_same_elements [ 'test/tmp/all.js' ], p.targets
  end
  
  def test_nil_target
    assert_nil AssetPackager.new.target
  end

  def test_callable_target
    common_options = { :target => lambda { |package| "test/tmp/compiled_with_%s.js" % [ File.basename(package.contents.last, '.js') ] } }
    p1 = AssetPackager.new(common_options.merge(:includes => [ 'test/fixtures/a.js' ]))
    p2 = AssetPackager.new(common_options.merge(:includes => [ 'test/fixtures/b.js' ]))
    
    assert_equal 'test/tmp/compiled_with_a.js', p1.target
    assert_equal 'test/tmp/compiled_with_b.js', p2.target
  end
  
  def test_dirty_with_missing_target
    sweep_tmp!
    p = AssetPackager.new(:target => 'test/tmp/all.js')
    assert !File.exist?(p.target),
      "Failed precondition: expected asset packager target file to not exist"
    
    assert p.dirty?,
      "Expected asset packager to be dirty when target file does not exist"
  end
  
  def test_dirty_when_source_file_is_newer_than_target_file
    sweep_tmp!
    p = AssetPackager.new(
      :target   => 'test/tmp/all.js',
      :includes => 'test/fixtures/*.js'
    )
    
    today     = Time.now
    yesterday = today - 86400 # 1 day
    
    FileUtils.touch(p.target)
    
    File.utime(yesterday, yesterday, p.target)
    File.utime(today, today, p.contents.first)
    
    assert p.dirty?,
      "Expected asset packager to be dirty when target file is older than source file"
  end
  
  def test_from_manifest
    yaml = YAML.load_file('test/fixtures/javascripts_manifest.yml')
    p = AssetPackager.from_manifest('test/fixtures/javascripts_manifest.yml')
    
    assert_equal yaml['prefix'] + yaml['target'], p.target,
      "Expected packager from manifest to read target"
    
    assert_precedes 'test/fixtures/b.js', 'test/fixtures/a.js', p.contents,
      "Expected packager from manifest to obey dependencies"
    
    assert !p.contents.include?('test/fixtures/c.js'),
      "Expected packager from manifest to exclude specified files"
    
    assert_same_elements Dir['test/fixtures/[^c].js'], p.contents
  end
  
  def test_subclass_from_manifest_symbolizes_keys
    p = CustomPackager.from_manifest('test/fixtures/custom_packager_manifest.yml')
    assert_equal 'fowl', p.initialization_options[:images_path]
  end
  
  def test_undeclared_dependencies_should_sort_alphabetically
    p = AssetPackager.new(
      :includes => 'test/fixtures/*.js',
      :dependencies => {
        'test/fixtures/a.js' => [ 'test/fixtures/b.js' ]
      }
    )
    assert_precedes 'test/fixtures/c.js', 'test/fixtures/d.js', p.contents
  end
  
  def test_files_with_no_dependencies_come_after_files_with_dependencies
    p = AssetPackager.new(
      :includes => 'test/fixtures/*.js',
      :dependencies => {
        'test/fixtures/a.js' => [ 'test/fixtures/b.js' ]
      }
    )
    assert_precedes 'test/fixtures/a.js', 'test/fixtures/c.js', p.contents
    assert_precedes 'test/fixtures/b.js', 'test/fixtures/c.js', p.contents
    assert_precedes 'test/fixtures/a.js', 'test/fixtures/d.js', p.contents
    assert_precedes 'test/fixtures/b.js', 'test/fixtures/d.js', p.contents
  end
  
  def test_package_requires_target
    assert_raises AssetPackager::NoTargetSpecifiedError do
      AssetPackager.new.package!
    end
  end
  
  def test_target_with_custom_path
    p = AssetPackager.new(
      :target   => 'pew/all.js',
      :includes => 'test/fixtures/*.js'
    )
    assert_equal 'pew/all.js', p.target
    assert_equal 'wop/pew/all.js', p.target(:target_path => 'wop')
  end

  def test_prefix
    p = AssetPackager.new(
      :target => 'all.js',
      :includes => [ 'fixtures/*.js' ],
      :excludes => [ 'fixtures/c.js', 'fixtures/e.js' ],
      :dependencies => {
        'fixtures/a.js' => [ 'fixtures/b.js' ]
      },
      :prefix => 'test'
    )

    assert_equal 'test/all.js', p.target
    assert_same_elements [ 'test/fixtures/a.js', 'test/fixtures/b.js', 'test/fixtures/d.js' ],
      p.contents
    assert_precedes 'test/fixtures/b.js', 'test/fixtures/a.js', p.contents
  end

  def test_digest
    assert_equal 'XrY7u-Ae7tCTyyK7j1rNww', AssetPackager.digest('hello world')
  end

  def test_id
    assert(AssetPackager.new.id.to_s.length > 0,
      "Expected to get an id")

    assert_equal(AssetPackager.new(:includes => 'test/fixtures/a.js').id,
      AssetPackager.new(:includes => 'fixtures/a.js', :prefix => 'test').id,
      "Expected packages with equivalent options (factored prefix) to generate same id")
  end
end
