require File.join(File.dirname(__FILE__), 'test_helper')

class JavascriptPackagerTest < Test::Unit::TestCase
  def setup
    sweep_tmp!
  end
  
  def test_package
    assert_package_generates_body(
      JavascriptPackager.new(
        :target   => 'test/tmp/all.js',
        :includes => 'test/fixtures/*.js',
        :excludes => 'test/fixtures/e.js'
      ),
      
      "function A(){};function B(){};function C(){};function D(){};\n"
    )
  end
  
end
