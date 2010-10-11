require File.join(File.dirname(__FILE__), 'test_helper')

class AssetPackagerTest < Test::Unit::TestCase
  def test_includes
    p = AssetPackager.new(:includes => 'test/fixtures/*.js')
    assert_same_elements Dir['test/fixtures/*.js'], p.contents
  end
  
  def test_multiple_includes
    p = AssetPackager.new(:includes => ['test/fixtures/a.js', 'test/fixtures/b.js'])
    assert_same_elements Dir['test/fixtures/{a,b}.js'], p.contents
  end
  
  def test_excludes
    p = AssetPackager.new(
      :includes => 'test/fixtures/*.js',
      :excludes => 'test/fixtures/b.js'
    )
    assert_same_elements Dir['test/fixtures/*[^b].js'], p.contents
  end
  
  def test_automatically_excludes_target
    p = AssetPackager.new(
      :target => 'test/fixtures/a.js',
      :includes => 'test/fixtures/*.js'
    )
    assert !p.contents.include?('test/fixtures/a.js'),
      "Expected packager to automatically exclude its target"
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
  
  def test_target
    p = AssetPackager.new(:target => 'test/tmp/all.js')
    assert_equal 'test/tmp/all.js', p.target
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
    
    yesterday = 1.day.ago
    today     = Time.now
    
    FileUtils.touch(p.target)
    File.utime(yesterday, yesterday, p.target)
    File.utime(today, today, p.contents.first)
    
    assert p.dirty?,
      "Expected asset packager to be dirty when target file is older than source file"
  end
  
  def test_from_manifest
    yaml = YAML.load_file('test/fixtures/manifest.yml')
    p = AssetPackager.from_manifest('test/fixtures/manifest.yml')
    
    assert_equal yaml['prefix'] + yaml['target'], p.target,
      "Expected packager from manifest to read target"
    
    assert_precedes 'test/fixtures/b.js', 'test/fixtures/a.js', p.contents,
      "Expected packager from manifest to obey dependencies"
    
    assert !p.contents.include?('test/fixtures/c.js'),
      "Expected packager from manifest to exclude specified files"
    
    assert_same_elements Dir['test/fixtures/[^c].js'], p.contents
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
  
  def test_package_to_target_path
    with_temp_dir('test/tmp2') do
      p = AssetPackager.new(
        :target => 'test/tmp/all.js',
        :includes => 'test/fixtures/*.js'
      )
      assert !File.exists?('test/tmp2/all.js')
      p.package!(:target_path => 'test/tmp2')
      assert !File.exists?('test/tmp/all.js'),
        "Expected packager not to have packaged to original target path when provided custom target path"
      assert File.exists?('test/tmp2/all.js'),
        "Expected packager to have packaged to custom target path"
    end
  end
  
  private
    def with_temp_dir(dirname)
      FileUtils.mkdir_p(dirname)
    ensure
      FileUtils.rm_rf(dirname)
    end
end
