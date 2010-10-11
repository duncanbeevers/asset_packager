class JavascriptPackager < AssetPackager
  def compress_command(src_paths, dest_path)
    "java -jar #{vendor_jar('closure-compiler')} --js_output_file #{dest_path} --warning_level QUIET " + src_paths.map { |p| "--js \"%s\"" % p }.join(' ')
  end
  
  def pre_concatenate?
    false
  end
end
