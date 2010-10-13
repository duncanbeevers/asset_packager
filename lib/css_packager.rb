class CssPackager < AssetPackager
  require 'base64'
  URL_REF = /url\([^\)]+\)/
  
  def initialize(options = {})
    @images_root = options[:images_root]
    super
  end
  
  def compress_command(src_paths)
    [ "java", "-jar", AssetPackager.vendor_jar('yuicompressor-2.4.2'),
      "--type", "css", src_paths
    ].flatten
  end
  
  def package!(options = {})
    super
    occurrence_counts = self.class.image_occurrence_counts_from_files(contents(options))
    
    Tempfile.open('buffer') do |buffer|
      # Concatenate all the css source files together,
      # replacing image urls with data uris if configured to do so
      contents(options).each_slice(20) do |filenames|
        Sheller.execute(*([ 'cat' ] + filenames + [ Sheller::STDOUT_APPEND_TO_FILE, buffer.path ]))
      end
      
      corpus = Sheller.execute(*compress_command([ buffer.path ])).stdout
      
      File.open(target(options), 'w') do |output_file|
        output_file << (@images_root ? self.class.encode_image_refs(corpus, @images_root, occurrence_counts) : corpus)
      end
    end
  end
  
  def self.encode_image_refs(body, images_root, occurrence_counts)
    body.gsub(URL_REF) do |m|
      # Assume domain-relative, absolute path urls
      path = path_from_match(m)
      
      if 1 == occurrence_counts[path]
        filename_on_disk = File.expand_path(File.join(images_root, path))
        mime_type        = "image/%s" % File.extname(path)[1..-1]
        
        "url(data:%s;base64,%s)" % [
          mime_type,
          Base64.encode64(File.read(filename_on_disk)).gsub("\n", '')
        ]
      else
        m
      end
    end
  end
  
  def self.image_occurrence_counts_from_files(filenames)
    occurrence_counts = Hash.new(0)
    
    filenames.each do |filename|
      File.read(filename).scan(URL_REF) do |m|
        occurrence_counts[path_from_match(m)] += 1
      end
    end
    
    occurrence_counts
  end
  
  def self.path_from_match(m)
    /([^\?]+)/.match(/url\(([^\)]+)\)/.match(m)[1])[1]
  end
end
