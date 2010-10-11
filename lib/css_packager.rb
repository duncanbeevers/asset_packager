class CssPackager < AssetPackager
  def compress_command(src_paths, dest_path)
    "java -jar #{vendor_jar('yuicompressor-2.4.2')} --type css -o #{dest_path} #{src_paths.first}"
  end
  
  def pre_concatenate?
    true
  end
end
