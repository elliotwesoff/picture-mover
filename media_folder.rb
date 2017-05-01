require './media_item'

class MediaFolder
  
  attr_accessor :path, :sha256_dictionary
  
  MEDIA_TYPES = [:jpg, :jpeg, :png, :gif, :mov, :mp4, :aae]
  
  def initialize
  end

  def sha_dictionary
    @sha256_dictionary ||= MediaItem.all.map(&:sha256)
  end
  
  def load_media(dir)
    files = Dir["#{dir}/**/*.*"]
    puts "Found #{files.count} items."
    reg = Regexp.new(MEDIA_TYPES.map { |m| "(.#{m}$)" }.join("|"))
    files.select! { |f| f.match(reg) }
    print "Loading #{files.count} media items... please be patient..."
    sleep 3
    files.each { |f| MediaItem.persist_item(f) }
    return MediaItem.count
  end
end