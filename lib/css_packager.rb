class CssPackager < AssetPackager
  require 'base64'
  
  def initialize(options = {})
    @images_root = options[:images_root]
    super
  end
  
  def compress_command(src_paths, dest_path)
    [ "java", "-jar", AssetPackager.vendor_jar('yuicompressor-2.4.2'),
      "--type", "css",
      "-o", dest_path, src_paths
    ].flatten
  end
  
  def package!(options = {})
    super
    
    Tempfile.open('buffer') do |buffer|
      # Concatenate all the css source files together,
      # replacing image urls with data uris if configured to do so
      contents(options).each do |filename|
        body = File.read(filename)
        buffer << (@images_root ? self.class.encode_image_refs(body, @images_root) : body)
      end
      buffer.flush
      
      Sheller.execute(*compress_command([buffer.path], target(options)))
    end
  end
  
  def self.encode_image_refs(body, images_root)
    body.gsub(/url\([^\)]+\)/) do |m|
      # Assume domain-relative, absolute path urls
      url              = /url\(([^\)]+)\)/.match(m)[1]
      path             = /([^\?]+)/.match(url)[1]
      filename_on_disk = File.expand_path(File.join(images_root, path))
      mime_type        = "image/%s" % File.extname(path)[1..-1]
      
      "url(data:%s;base64,%s)" % [
        mime_type,
        Base64.encode64(File.read(filename_on_disk)).gsub("\n", '')
      ]
    end
  end
end
