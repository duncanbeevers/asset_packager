class AssetPackager
  module RailsHelper
    def package_assets?
      true
    end
    
    def packaged_stylesheet_link_tag(package)
      files = package_assets? && package.mhtml? ?
        [ package.mhtml_root ] : package_files(package, ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR)
      
      stylesheet_link_tag(*files)
    end
    
    def packaged_javascript_include_tag(package)
      javascript_include_tag(*package_files(package, ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR))
    end
    
    private
    def package_files(package, base_directory_name)
      base_directory = Pathname.new(base_directory_name)
      (package_assets? ? [ package.target ] : package.contents).map do |asset_path|
        Pathname.new(File.expand_path(asset_path)).relative_path_from(base_directory).to_s
      end
    end
  end
end
