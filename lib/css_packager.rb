class CssPackager < AssetPackager
  URL_REF                   = /url\([^\)]+\)/
  URL_RULE_REF              = /(?:^|[^\}]+)url\([^\)]+\)[^\}]*\}/
  SHORTHAND_BACKGROUND_REF  = /background:([^;]+)/
  SELECTOR_STYLE_REF        = /([^\{]+)\{([^\}]+)\}/
  BACKGROUND_STYLE_REF      = /([\S]+)\s+(url\([^\)]+\))/
  
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
  
  attr_reader :mhtml_root
  
  def initialize(options = {})
    super
    @assets_root = options[:assets_root]
    @mhtml_root  = options[:mhtml_root]
    @partition_assets = options[:partition_assets]
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

      if partition_assets
        asset_refs_body = self.class.partition_asset_refs!(body, @assets_root, @mhtml_root)

        File.open(partition_assets(options), 'w') do |partition_file|
          partition_file << self.class.embed_assets(asset_refs_body, @assets_root, @mhtml_root)
        end
        File.open(target(options), 'w') do |output_file|
          output_file << body
        end
      else
        File.open(target(options), 'w') do |output_file|
          output_file << self.class.embed_assets(body, @assets_root, @mhtml_root)
        end
      end
    end
  end
  
  def mhtml?
    !!(@assets_root && @mhtml_root)
  end

  def targets(options = {})
    partition_assets ?
      [ target(options), partition_assets(options) ] :
      super
  end

  def partition_assets(options = {})
    stem = nil
    if true == @partition_assets
      t = target(options)
      if t
        ext = File.extname(t)
        stem = File.join(File.dirname(t), "%s-resources%s" % [ File.basename(t, ext), ext ])
      end
    else
      stem = prefix_path(@partition_assets)
    end

    options[:target_path] ?
      File.join(options[:target_path], stem) :
      stem
  end

  protected
  def id_seed
    [ super,
      @mhtml_root && @assets_root,
      @assets_root,
      @partition_assets
    ].compact.join
  end

  def self.compress_command(src_paths)
    [ "java", "-jar", AssetPackager.vendor_jar('yuicompressor-2.4.2'),
      "--type", "css", src_paths
    ].flatten
  end
  
  def self.partition_asset_refs!(body, assets_root, mhtml_root)
    partitioned_rules = []

    body.gsub!(URL_RULE_REF) do |m|
      shorthand = SHORTHAND_BACKGROUND_REF.match(m)
      replacement_rule = ''

      if shorthand
        _, selector, styles = *SELECTOR_STYLE_REF.match(m)
        color, image, repeat, xpos, ypos, attachment = nil
        styles.gsub!(SHORTHAND_BACKGROUND_REF) do |m2|
          _, background_styles = *SHORTHAND_BACKGROUND_REF.match(m2)
          _, color, image = *BACKGROUND_STYLE_REF.match(background_styles)

          background_styles.gsub!(BACKGROUND_STYLE_REF, '')

          if image
            repeat, xpos, ypos, attachment = background_styles.split(' ')
          else
            image, repeat, xpos, ypos, attachment = background_styles.split(' ')
          end

          [
            color ? "background-color:#{color}" : nil,
            repeat ? "background-repeat:#{repeat}" : nil,
            xpos && ypos ? "background-position:#{xpos} #{ypos}" : nil,
            xpos && !ypos ? "background-position-x:#{xpos}" : nil,
            attachment ? "background-attachment:#{attachment}" : nil
          ].compact.join(';')
        end

        replacement_rule = "#{selector}{#{styles}}"
        m = "#{selector}{background-image:#{image};}"
      end

      partitioned_rules.push(m)
      replacement_rule
    end

    partitioned_rules.join
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

      if 1 == occurrence_counts[path]
        filename         = File.expand_path(File.join(assets_root, path))
        content_location = "%s%s" % [ AssetPackager.digest(path), File.extname(path) ]

        mhtml_head.push(MHTML_PART % [ content_location, mime_type(path), base64_encode_file(filename) ])

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
