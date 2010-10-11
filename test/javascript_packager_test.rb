require File.join(File.dirname(__FILE__), 'test_helper')

class JavascriptPackagerTest < Test::Unit::TestCase
  def test_package
    sweep_tmp!
    p = JavascriptPackager.new(
      :target   => 'test/tmp/all.js',
      :includes => 'test/fixtures/*.js'
    )
    p.package!
    assert File.exists?(p.target)
  end
  
end
