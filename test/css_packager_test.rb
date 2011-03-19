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

  def test_mhtml
    assert CssPackager.new(
        :assets_root => 'test/fixtures',
        :mhtml_root  => 'http://www.example.com/mthml.css'
      ).mhtml?,
      "Expected css package with assets root and mhtml root to be mhtml"
  end

  def test_mhtml_requires_assets_root
    assert !CssPackager.new(
        :mhtml_root  => 'http://www.example.com/mthml.css'
      ).mhtml?,
      "Expected css package with mthml root and no assets root not to be mhtml"
  end

  def test_encode_png_as_mhtml
    assert_package_generates_body(
      CssPackager.new(
        :target      => 'test/tmp/all.css',
        :includes    => 'test/fixtures/b.css',
        :assets_root => 'test/fixtures',
        :mhtml_root  => 'http://www.kongregate.com/stylesheets/all.css'
      ),
      
      "/*\r\nContent-Type: multipart/related; boundary=\"MHTML_MARK\"\r\n\r\n--MHTML_MARK\r\nContent-Location: slK9kH1St5naLvct9uLWLA.png\r\nContent-Type: image/png\r\nContent-Transfer-Encoding: base64\r\n\r\niVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==\r\n--MHTML_MARK--\r\n*/\r\n.css_rule_b{background-image:url(mhtml:http://www.kongregate.com/stylesheets/all.css!slK9kH1St5naLvct9uLWLA.png);}"
    )
  end

  def test_partition
    partitioned_assets_path = 'test/tmp/all-resources.css'
    package = CssPackager.new(
      :target           => 'test/tmp/all.css',
      :includes         => [ 'test/fixtures/a.css', 'test/fixtures/b.css' ],
      :dependencies     => { 'test/fixtures/a.css' => [ 'test/fixtures/b.css' ] },
      :assets_root      => 'test/fixtures',
      :partition_assets => partitioned_assets_path
    )

    assert_package_generates_body(
      package,
      '.css_rule_a{background-color:transparent;}'
    )

    assert_package_generates_resource(
      package,
      partitioned_assets_path,
      ".css_rule_b{background-image:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==);}"
    )
  end

  def test_partition_with_shorthand_background_rule
    partitioned_assets_path = 'test/tmp/all-resources.css'
    package = CssPackager.new(
      :target           => 'test/tmp/all.css',
      :includes         => [ 'test/fixtures/a.css', 'test/fixtures/e.css' ],
      :dependencies     => { 'test/fixtures/a.css' => [ 'test/fixtures/e.css' ] },
      :assets_root      => 'test/fixtures',
      :partition_assets => partitioned_assets_path
    )

    assert_package_generates_body(
      package,
      '.css_rule_e1{height:80px;background-color:transparent;background-repeat:no-repeat;background-position-x:0;}.css_rule_e2{height:25px;background-color:transparent;background-repeat:no-repeat;background-position:0 0;background-attachment:fixed;color:#fff;}.css_rule_a{background-color:transparent;}'
    )

    assert_package_generates_resource(
      package,
      partitioned_assets_path,
      ".css_rule_e1{background-image:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==);}.css_rule_e2{background-image:url(data:image/gif;base64,R0lGODlhAQABAIAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==);}"
    )
  end

  def test_partition_with_malformed_shorthand_background_rule
    partitioned_assets_path = 'test/tmp/f-resources.css'
    package = CssPackager.new(
      :target           => 'test/tmp/f.css',
      :includes         => 'test/fixtures/f.css',
      :partition_assets => partitioned_assets_path)

    assert_package_generates_body(
      package,
      '.css_rule_f{background-repeat:no-repeat;background-position:0 0;background-attachment:fixed;}'
    )

    assert_package_generates_resource(
      package,
      partitioned_assets_path,
      '.css_rule_f{background-image:url(/images/1x1.png);}'
    )
  end

  def test_partition_with_mhtml_does_not_wrap_primary
    partitioned_assets_path = 'test/tmp/f-resources.css'
    package = CssPackager.new(
      :target           => 'test/tmp/b.css',
      :includes         => 'test/fixtures/f.css',
      :assets_root      => 'test/fixtures',
      :mhtml_root       => 'http://www.example.com/f.css',
      :partition_assets => partitioned_assets_path)

    assert_package_generates_body(
      package,
      '.css_rule_f{background-repeat:no-repeat;background-position:0 0;background-attachment:fixed;}'
    )

    assert_package_generates_resource(
      package,
      partitioned_assets_path,
      "/*\r\nContent-Type: multipart/related; boundary=\"MHTML_MARK\"\r\n\r\n--MHTML_MARK\r\nContent-Location: slK9kH1St5naLvct9uLWLA.png\r\nContent-Type: image/png\r\nContent-Transfer-Encoding: base64\r\n\r\niVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==\r\n--MHTML_MARK--\r\n*/\r\n.css_rule_f{background-image:url(mhtml:http://www.example.com/f.css!slK9kH1St5naLvct9uLWLA.png);}"
    )
  end

  def test_partition_with_mhtml_and_no_assets_root_does_not_wrap_partition
    partitioned_assets_path = 'test/tmp/f-resources.css'
    package = CssPackager.new(
      :target           => 'test/tmp/b.css',
      :includes         => 'test/fixtures/f.css',
      :mhtml_root       => 'http://www.example.com/f.css',
      :partition_assets => partitioned_assets_path)

    assert_package_generates_body(
      package,
      '.css_rule_f{background-repeat:no-repeat;background-position:0 0;background-attachment:fixed;}'
    )

    assert_package_generates_resource(
      package,
      partitioned_assets_path,
      ".css_rule_f{background-image:url(/images/1x1.png);}"
    )
  end

  def test_partition_with_derived_filename
    package = CssPackager.new(:target => 'test/tmp/all.css', :includes => [ 'test/tmp/b.css' ], :partition_assets => true)
    assert_same_elements([ 'test/tmp/all.css', 'test/tmp/all-resources.css' ], package.targets)
  end

  def test_targets
    package = CssPackager.new(:target => 'test/tmp/all.css')
    assert_same_elements([ 'test/tmp/all.css' ], package.targets)
  end

  def test_targets_with_partition
    package = CssPackager.new(:prefix => 'test', :target => 'tmp/all.css', :partition_assets => 'tmp/all-resources.css')
    assert_same_elements([ 'test/tmp/all.css', 'test/tmp/all-resources.css' ],
      package.targets)
    assert_same_elements([ 'custom_prefix/test/tmp/all.css', 'custom_prefix/test/tmp/all-resources.css' ],
      package.targets(:target_path => 'custom_prefix'))
  end

  def test_id
    assert_not_equal CssPackager.new.id, CssPackager.new(:assets_root => 'test/fixtures').id,
      "Expected specifying assets_root to have changed package id"

    assert_not_equal CssPackager.new.id, CssPackager.new(:partition_assets => true).id,
      "Expected specifying partition_assets to have changed package id"

    assert_equal CssPackager.new.id, CssPackager.new(:mhtml_root => true).id,
      "Expected specifying mhtml_root without assets_root not to have changed package id"
  end
end
