class CssPackager < AssetPackager
  def compress_command(src_paths, dest_path)
    [ "java", "-jar", AssetPackager.vendor_jar('yuicompressor-2.4.2'),
      "--type", "css",
      "-o", dest_path, src_paths
    ].flatten
  end
  
  def package!(options = {})
    super
    
    Tempfile.open('buffer') do |buffer|
      contents(options).each_slice(20) do |filenames|
        Sheller.execute(*[ 'cat', filenames, Sheller::STDOUT_APPEND_TO_FILE, buffer.path].flatten)
      end
      Sheller.execute('echo', ';', Sheller::STDOUT_APPEND_TO_FILE, buffer.path)
      Sheller.execute(*compress_command([buffer.path], target(options)))
    end
  end
end
