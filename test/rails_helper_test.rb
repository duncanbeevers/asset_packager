require File.join(File.dirname(__FILE__), 'test_helper')

module Rails
end

load File.join(File.dirname(__FILE__), '../init.rb')

class ActionControllerHelper
  include AssetPackager::RailsHelper
end

class ActionControllerHelperWithoutPackageAssets < ActionControllerHelper
  def package_assets?
    false
  end
end

class AssetPackagerRailsHelperTest < Test::Unit::TestCase
  def test_package_assets
    helper = ActionControllerHelper.new
    assert helper.package_assets?
  end
  
  def test_helper_can_override_package_assets
    helper = ActionControllerHelperWithoutPackageAssets.new
    assert !helper.package_assets?
  end
end
