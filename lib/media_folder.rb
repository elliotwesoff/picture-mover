require './media_item'

class MediaFolder
  
  attr_accessor :path, :sha256_dictionary, :file_dictionary, :directory_contents, :reject_filetypes, :library
  
  MEDIA_TYPES = [:jpg, :jpeg, :png, :gif, :mov, :mp4, :aae]
  
  def initialize(dir, options = {})
    @path = dir
    @reject_filetypes = options[:omit_filetypes] || []
    @directory_contents = []
    @library = []
    FileUtils.mkdir_p(@path)
  end

  def file_dictionary
    @file_dictionary ||= library.map(&:file_path)
  end
  
  def sha_dictionary
    @sha256_dictionary ||= library.map(&:sha256)
  end
  
  def load_media
    files = Dir["#{path}/**/*.*"]
    reg = Regexp.new(MEDIA_TYPES.reject { |m| reject_filetypes.include?(m.to_s) }.map { |m| "(.#{m}$)" }.join("|"), 'i')
    @directory_contents = files.select { |f| f.match(reg) }
    puts "#{path}: Rejected #{files.count - @directory_contents.count} items."
    return @directory_contents
  end

  def build_library
    # TODO: figure out why raising the slice number raises this error:
    # Too many open files @ rb_sysopen
    @library = []
    directory_contents.each_slice(100) do |chunk|
      chunk.map do |path|
        Thread.new { library << MediaItem.new(path) }
      end.map(&:join)
    end
  end

  def filter_duplicates
    duplicates = library.group_by(&:sha256).select { |a, b| b.count > 1 }
    counter = 0
    duplicates.each do |sha256, media_items| 
      media_items.shift
      media_items.each { |mi| library.delete(mi) }
      counter += media_items.count
    end
    puts "#{path}: Filtered #{duplicates.count} duplicate items."
  end
  
  def rename_conflicting_files
    # TODO: get the god damn ActiveRecord::QueryMethods module in here. god damn ridiculous.
    conflicting_names = library.group_by { |mi| File.basename(mi.file_path) }.values
    conflicting_names.select { |x| x.length > 1 }.each do |items|
      items.each do |item|
        dir = File.dirname(item.file_path)
        ext = File.extname(item.file_path)
        entry = library.find { |x| x.file_path == item.file_path }
        entry.file_path = "#{dir}/#{item.sha256}#{ext}"
      end
    end
  end

end
