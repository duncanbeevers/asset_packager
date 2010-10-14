class CssPackager < AssetPackager
  require 'base64'
  require 'digest/md5'
  
  URL_REF = /url\([^\)]+\)/
  
  EMBED_MIME_TYPES = {
    '.png'  => 'image/png',
    '.jpg'  => 'image/jpeg',
    '.jpeg' => 'image/jpeg',
    '.gif'  => 'image/gif',
    '.tif'  => 'image/tiff',
    '.tiff' => 'image/tiff',
    '.ttf'  => 'font/truetype',
    '.otf'  => 'font/opentype',
    '.woff' => 'font/woff'
  }
  
  MHTML_START     = "/*\r\nContent-Type: multipart/related; boundary=\"MHTML_MARK\"\r\n"
  MHTML_SEPARATOR = "\r\n--MHTML_MARK"
  MHTML_PART      = "\r\nContent-Location: %s\r\nContent-Type: %s\r\nContent-Transfer-Encoding: base64\r\n\r\n%s"
  MHTML_END       = "--\r\n*/\r\n"
  MHTML_PART_REF  = "url(mhtml:%s!%s)"
  DATA_URI_REF    = "url(data:%s;base64,%s)"
  
  def initialize(options = {})
    @assets_root = options[:assets_root]
    @mhtml_root  = options[:mhtml_root]
    super
  end
  
  def package!(options = {})
    super
    
    Tempfile.open('buffer') do |buffer|
      # Concatenate all the css source files together,
      # replacing image urls with data uris if configured to do so
      contents(options).each_slice(20) do |filenames|
        Sheller.execute(*([ 'cat' ] + filenames + [ Sheller::STDOUT_APPEND_TO_FILE, buffer.path ]))
      end
      body = Sheller.execute(*self.class.compress_command([ buffer.path ])).stdout
      
      File.open(target(options), 'w') do |output_file|
        output_file << self.class.embed_assets(body, @assets_root, @mhtml_root)
      end
    end
  end
  
  def mhtml?
    !!@mhtml_root
  end
  
  def self.compress_command(src_paths)
    [ "java", "-jar", AssetPackager.vendor_jar('yuicompressor-2.4.2'),
      "--type", "css", src_paths
    ].flatten
  end
  
  def self.embed_assets(body, assets_root, mhtml_root)
    if assets_root && mhtml_root
      mhtml_wrap_asset_refs(body, assets_root, mhtml_root)
    elsif assets_root
      base64_encode_asset_refs(body, assets_root)
    else
      body
    end
  end
  
  def self.base64_encode_asset_refs(body, assets_root)
    occurrence_counts = asset_occurrence_counts(body)
    
    body.gsub(URL_REF) do |m|
      # Assume domain-relative, absolute path urls
      path = path_from_match(m)
      
      if 1 == occurrence_counts[path]
        filename = File.expand_path(File.join(assets_root, path))
        
        DATA_URI_REF % [ mime_type(path), base64_encode_file(filename) ]
      else
        m
      end
    end
  end
  
  def self.mhtml_wrap_asset_refs(body, assets_root, mhtml_root)
    occurrence_counts = asset_occurrence_counts(body)
    mhtml_head = [ MHTML_START ]
    
    mhtml_body = body.gsub(URL_REF) do |m|
      path             = path_from_match(m)
      filename         = File.expand_path(File.join(assets_root, path))
      base64           = base64_encode_file(filename)
      
      content_location = "%s%s" % [ Digest::MD5.hexdigest(path), File.extname(path) ]
      
      if 1 == occurrence_counts[path]
        filename = File.expand_path(File.join(assets_root, path))
        
        mhtml_head.push(MHTML_PART % [ content_location, mime_type(path), base64 ])
        MHTML_PART_REF % [ mhtml_root, content_location ]
      else
        m
      end
    end
    
    mhtml_head.push(MHTML_END)
    
    "%s%s" % [
      mhtml_head.join(MHTML_SEPARATOR),
      mhtml_body
    ]
  end
  
  def self.base64_encode_file(filename)
    Base64.encode64(File.read(filename)).gsub("\n", '')
  end
  
  def self.asset_occurrence_counts(body)
    occurrence_counts = Hash.new(0)
    
    body.scan(URL_REF) do |m|
      occurrence_counts[path_from_match(m)] += 1
    end
    
    occurrence_counts
  end
  
  def self.path_from_match(m)
    /([^\?]+)/.match(/url\(([^\)]+)\)/.match(m)[1])[1]
  end
  
  def self.mime_type(path)
    EMBED_MIME_TYPES[File.extname(path).downcase]
  end
end
