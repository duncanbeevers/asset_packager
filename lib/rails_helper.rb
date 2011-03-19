require 'json'

class AssetPackager
  module RailsHelper
    def package_assets?
      true
    end
    
    def packaged_stylesheet_link_tag(package)
      package.inline? ?
        stylesheet_tag(package_body(package)) :
        stylesheet_link_tag(*package_file_urls(package))
    end
    
    def packaged_javascript_include_tag(package, *args)
      package.inline? ?
        javascript_tag(package_body(package, *args)) :
        javascript_include_tag(*package_files(package, ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR))
    end
    
    def package_file_urls(package)
      filenames = nil
      
      if package.mhtml?
        if package_assets?
          filenames = [ package.mhtml_root ]
        else
          _, protocol_and_host = *(/^([^:]+:\/\/[^\/]+)/.match(package.mhtml_root))
          begin
            original_asset_host = ActionController::Base.asset_host
            ActionController::Base.asset_host = protocol_and_host
            urls = 
            filenames = package_files(package, ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR)
          ensure
            ActionController::Base.asset_host = original_asset_host
          end
        end
      else
        filenames = package_files(package, ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR)
      end
      filenames.map do |filename|
        compute_public_path(filename, 'stylesheets', 'css')
      end
    end

    def package_partition_file_urls(package)
      package_partition_files(package, ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR).map do |filename|
        compute_public_path(filename, 'stylesheets', 'css')
      end
    end

    def package_body(package, *args)
      args.unshift(
        package_assets? ?
          package.packaged_body :
          package.unpackaged_body).join
    end

    private
    def package_files(package, base_directory_name)
      paths_to_package_files(base_directory_name, package.target, package.contents)
    end

    def package_partition_files(package, base_directory_name)
      paths_to_package_files(base_directory_name, package.partition_assets, [] )
    end

    def paths_to_package_files(base_directory_name, packaged_asset_filename, unpackaged_asset_filenames)
      base_directory = Pathname.new(base_directory_name)
      (package_assets? && packaged_asset_filename ? [ packaged_asset_filename ] : unpackaged_asset_filenames).map do |asset_path|
        Pathname.new(File.expand_path(asset_path)).relative_path_from(base_directory).to_s
      end
    end
  end
end
