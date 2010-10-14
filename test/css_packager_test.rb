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
  
  def test_does_not_encode_without_assets_root
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
        :assets_root => 'test/fixtures'
      ),
      
      ".css_rule_b{background-image:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==);}"
    )
  end
  
  def test_encode_gif_as_data_uri
    assert_package_generates_body(
      CssPackager.new(
        :target      => 'test/tmp/all.css',
        :includes    => 'test/fixtures/c.css',
        :assets_root => 'test/fixtures'
      ),
      
      ".css_rule_c{background-image:url(data:image/gif;base64,R0lGODlhAQABAIAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==);}"
    )
  end
  
  def test_does_not_encode_duplicated_files
    assert_package_generates_body(
      CssPackager.new(
        :target      => 'test/tmp/all.css',
        :includes    => 'test/fixtures/d.css',
        :assets_root => 'test/fixtures'
      ),
      
      ".css_rule_d1{background-image:url(/images/1x1.png);}.css_rule_d2{background-image:url(/images/1x1.png?1);}"
    )
  end
  
  def test_encode_png_as_mhtml
    assert_package_generates_body(
      CssPackager.new(
        :target      => 'test/tmp/all.css',
        :includes    => 'test/fixtures/b.css',
        :assets_root => 'test/fixtures',
        :mhtml_root  => 'http://www.kongregate.com/stylesheets/all.css'
      ),
      
      "/*\r\nContent-Type: multipart/related; boundary=\"MHTML_MARK\"\r\n\r\n--MHTML_MARK\r\nContent-Location:1-1x1.png\r\nContent-Type:image/png\r\nContent-Transfer-Encoding:base64\r\n\r\niVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==\r\n--MHTML_MARK--\r\n*/\r\n.css_rule_b{background-image:url(mhtml:http://www.kongregate.com/stylesheets/all.css!1-1x1.png);}"
    )
  end
end
