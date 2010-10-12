require File.join(File.dirname(__FILE__), 'test_helper')

class CssPackagerTest < Test::Unit::TestCase
  def setup
    sweep_tmp!
  end
  
  def test_package
    assert_package_generates_body(
      CssPackager.new(
        :target   => 'test/tmp/all.css',
        :includes => 'test/fixtures/a.css'
      ),
      
      ".css_rule_a{background-color:transparent;}"
    )
  end
  
  def test_does_not_encode_without_images_root
    assert_package_generates_body(
      CssPackager.new(
        :target      => 'test/tmp/all.css',
        :includes    => 'test/fixtures/b.css'
      ),
      
      ".css_rule_b{background-image:url(/images/1x1.png?1);}"
    )
  end
  
  def test_encode_png_as_data_uri
    assert_package_generates_body(
      CssPackager.new(
        :target      => 'test/tmp/all.css',
        :includes    => 'test/fixtures/b.css',
        :images_root => 'test/fixtures'
      ),
      
      ".css_rule_b{background-image:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==);}"
    )
  end
  
  def test_encode_gif_as_data_uri
    assert_package_generates_body(
      CssPackager.new(
        :target      => 'test/tmp/all.css',
        :includes    => 'test/fixtures/c.css',
        :images_root => 'test/fixtures'
      ),
      
      ".css_rule_c{background-image:url(data:image/gif;base64,R0lGODlhAQABAIAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==);}"
    )
  end
end
