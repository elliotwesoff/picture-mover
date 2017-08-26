require 'digest'
require './media_item'

class MediaFolder
  
  attr_accessor :path, :sha256_dictionary, :file_dictionary, :directory_contents, :reject_filetypes, :library
  
  MEDIA_TYPES = [:jpg, :jpeg, :png, :gif, :mov, :mp4, :aae]
  
  def initialize(dir, reject_filetypes = [])
    @path = dir
    @reject_filetypes = reject_filetypes
    @directory_contents = []
    @library = []
    FileUtils.mkdir_p(@path)
  end

  def file_dictionary
    @file_dictionary ||= MediaItem.all.map(&:file_name)
  end
  
  def sha_dictionary
    @sha256_dictionary ||= MediaItem.all.map(&:sha256)
  end
  
  def load_media
    files = Dir["#{path}/**/*.*"]
    reg = Regexp.new(MEDIA_TYPES.reject { |m| reject_filetypes.include?(m) }.map { |m| "(.#{m}$)" }.join("|"), 'i') # todo: test the reject.
    @directory_contents = files.select { |f| f.match(reg) }
    puts "Found #{files.count} items. #{@directory_contents.count} remain post-filter."
    return @directory_contents
  end

  def build_library
    @library = []
    puts "Calculating ..."
    # TODO: figure out why raising the slice number raises this error:
    # Too many open files @ rb_sysopen
    directory_contents.each_slice(100) do |chunk|
      chunk.map do |path|
        Thread.new { library_entry(path) }
      end.map(&:join)
    end
    return library
  end

  def filter_duplicates
  end
  
  def rename_conflicting_files
    conflicting_names = library.group_by { |x| File.basename(x[:path]) }.values
    conflicting_names.select { |x| x.length > 1 }.each do |items|
      items.each do |item|
        dir = File.dirname(item[:path])
        ext = File.extname(item[:path])
        entry = library.find { |x| x[:path] == item[:path] }
        entry[:path] = "#{dir}/#{item[:sha256]}#{ext}"
      end
    end
  end

  private

  def library_entry(path)
    library << { path: path, sha256: Digest::SHA256.hexdigest(File.open(path).read) }
  end

end