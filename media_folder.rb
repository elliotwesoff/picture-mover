require './media_item'

class MediaFolder
  
  attr_accessor :path, :sha256_dictionary, :file_dictionary
  
  MEDIA_TYPES = [:jpg, :jpeg, :png, :gif, :mov, :mp4, :aae]
  
  def initialize
  end

  def file_dictionary
    @file_dictionary ||= MediaItem.all.map(&:file_name)
  end
  
  def sha_dictionary
    @sha256_dictionary ||= MediaItem.all.map(&:sha256)
  end
  
  def load_media(dir, reject_filetypes = [])
    files = Dir["#{dir}/**/*.*"]
    puts "Found #{files.count} items."
    reg = Regexp.new(MEDIA_TYPES.reject { |m| reject_filetypes.include?(m) }.map { |m| "(.#{m}$)" }.join("|")) # todo: test the reject.
    return files.select { |f| f.match(reg) }
  end
end