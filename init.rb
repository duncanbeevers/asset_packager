$:.unshift(File.dirname(__FILE__) + '/lib')

require 'asset_packager'
require 'javascript_packager'
require 'css_packager'

require 'rails_helper' if defined?(Rails)
