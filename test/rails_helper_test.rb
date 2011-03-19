require File.join(File.dirname(__FILE__), 'test_helper')

# Mock Rails
module Rails
end

module ActionView
  module Helpers
    module AssetTagHelper
      JAVASCRIPTS_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'tmp/public/javascripts/'))
      STYLESHEETS_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'tmp/public/stylesheets/'))

      private
      def compute_public_path(source, dir, ext = nil, include_host = true)
        source
      end
    end
  end
end

load File.join(File.dirname(__FILE__), '../init.rb')

class PackagingHelper
  include AssetPackager::RailsHelper
  include ActionView::Helpers::AssetTagHelper
  
  def stylesheet_link_tag(*files)
    ('<link href="%s" type="text/css" />' * files.length) % files
  end
  
  def javascript_include_tag(*files)
    ('<script src="%s" type="text/javascript"></script>' * files.length) % files
  end
  
  def javascript_tag(source)
    '<script type="text/javascript">%s</script>' % source
  end
  
  def stylesheet_tag(source)
    '<style rel="stylesheet" type="text/css">%s</style>' % source
  end
end

class NonPackagingHelper < PackagingHelper
  def package_assets?
    false
  end
end

class AssetPackagerRailsHelperTest < Test::Unit::TestCase
  def test_package_assets
    helper = PackagingHelper.new
    assert helper.package_assets?
  end
  
  def test_helper_can_override_package_assets
    helper = NonPackagingHelper.new
    assert !helper.package_assets?
  end
  
  def test_packaged_stylesheet_link_tag
    helper = PackagingHelper.new
    packager = CssPackager.new(
      :target   => 'test/tmp/public/stylesheets/all.css',
      :includes => [ 'test/fixtures/a.css', 'test/fixtures/b.css' ]
    )
    
    assert_equal('<link href="all.css" type="text/css" />',
      helper.packaged_stylesheet_link_tag(packager))
  end
  
  def test_packaged_stylesheet_link_tag_nonpackaged
    helper = NonPackagingHelper.new
    packager = CssPackager.new(
      :target   => 'test/tmp/public/stylesheets/all.css',
      :includes => [ 'test/fixtures/a.css', 'test/fixtures/b.css' ]
    )
    
    assert_equal(
      '<link href="../../../fixtures/a.css" type="text/css" /><link href="../../../fixtures/b.css" type="text/css" />',
      helper.packaged_stylesheet_link_tag(packager)
    )
  end
  
  def test_packaged_stylesheet_link_tag_inline
    helper = PackagingHelper.new
    packager = CssPackager.new(
      :target   => 'test/tmp/public/stylesheets/all.css',
      :includes => [ 'test/fixtures/a.css', 'test/fixtures/b.css' ],
      :inline   => true
    )
    
    assert_equal(
      "<style rel=\"stylesheet\" type=\"text/css\">.css_rule_a{background-color:transparent;}.css_rule_b{background-image:url(/images/1x1.png?1);}</style>",
      helper.packaged_stylesheet_link_tag(packager)
    )
  end
  
  def test_packaged_stylesheet_link_tag_nonpackaged_inline
    helper = NonPackagingHelper.new
    packager = CssPackager.new(
      :includes => [ 'test/fixtures/a.css', 'test/fixtures/b.css' ],
      :inline   => true
    )
    
    assert_equal(
      "<style rel=\"stylesheet\" type=\"text/css\">.css_rule_a { background-color: transparent; }\n.css_rule_b { background-image: url(/images/1x1.png?1); }\n</style>",
      helper.packaged_stylesheet_link_tag(packager)
    )
  end
  
  def test_packaged_javascript_include_tag
    helper = PackagingHelper.new
    packager = JavascriptPackager.new(
      :target   => 'test/tmp/public/javascripts/all.js',
      :includes => [ 'test/fixtures/a.js', 'test/fixtures/b.js' ]
    )
    
    assert_equal(
      '<script src="all.js" type="text/javascript"></script>',
      helper.packaged_javascript_include_tag(packager)
    )
  end
  
  def test_packaged_javascript_include_tag_nonpackaged
    helper = NonPackagingHelper.new
    packager = JavascriptPackager.new(
      :target   => 'test/tmp/public/javascripts/all.js',
      :includes => [ 'test/fixtures/a.js', 'test/fixtures/b.js' ]
    )
    
    assert_equal(
      '<script src="../../../fixtures/a.js" type="text/javascript"></script><script src="../../../fixtures/b.js" type="text/javascript"></script>',
      helper.packaged_javascript_include_tag(packager)
    )
  end
  
  def test_packaged_javascript_include_tag_inline
    helper = PackagingHelper.new
    packager = JavascriptPackager.new(
      :target   => 'test/tmp/public/javascripts/all.js',
      :includes => [ 'test/fixtures/a.js', 'test/fixtures/b.js' ],
      :inline   => true
    )
    
    assert_equal(
      "<script type=\"text/javascript\">function A(){};function B(){};\n</script>",
      helper.packaged_javascript_include_tag(packager)
    )
  end
  
  def test_packaged_javascript_include_tag_nonpackaged_inline
    helper = NonPackagingHelper.new
    packager = JavascriptPackager.new(
      :includes => [ 'test/fixtures/a.js', 'test/fixtures/b.js' ],
      :inline   => true
    )
    
    assert_equal(
      "<script type=\"text/javascript\">function A() {}\nfunction B() {}\n</script>",
      helper.packaged_javascript_include_tag(packager)
    )
  end

  def test_packaged_javascript_include_tag_with_arguments_packaged_inline
    helper = PackagingHelper.new
    packager = JavascriptPackager.new(
      :target   => 'test/tmp/public/javascripts/with_args.js',
      :includes => [ 'test/fixtures/e.js' ],
      :inline   => true
    )

    assert_equal(
      "function Constructor(a){console.log(\"evacuate!\")};\nalert('freeze');",
      helper.package_body(packager, "alert('freeze');")
    )
  end

  def test_packaged_javascript_include_tag_with_arguments_nonpackaged_inline
    helper = NonPackagingHelper.new
    packager = JavascriptPackager.new(
      :includes => [ 'test/fixtures/e.js' ],
      :inline   => true
    )

    assert_equal(
      "function Constructor(arg) {\n  console.log(\"evacuate!\");\n}\n\nalert('freeze');",
      helper.package_body(packager, "alert('freeze');")
    )
  end

  def test_package_partition_file_urls_nonpackaged
    helper = NonPackagingHelper.new
    packager = CssPackager.new(
      :includes         => [ 'test/fixtures/b.css' ],
      :partition_assets => 'test/tmp/partition.css'
    )

    assert_same_elements [], helper.package_partition_file_urls(packager)
  end

  def test_package_partition_file_urls_packaged
    helper = PackagingHelper.new
    packager = CssPackager.new(
      :includes         => [ 'test/fixtures/b.css' ],
      :partition_assets => 'test/tmp/partition.css'
    )

    assert_same_elements [ '../../partition.css' ], helper.package_partition_file_urls(packager)
  end
end
