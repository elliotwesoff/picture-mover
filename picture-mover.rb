require 'rubygems'
require 'fileutils'
require 'digest'
require 'pry'


class UserInput

  attr_accessor :last_ans

  def initialize
  end

  def get_input(name = nil)
    ans = gets
    ans.downcase!
    ans.chomp!
    ans.strip!
    # handle backslashes properly for windows and linux paths.
    ans[0...2].match(/[A-Z]:/i) ? ans.gsub!(/\\/, "/") : ans.gsub!(/\\/, "")
    @last_ans = ans
    record_answer(name, ans) if name
    return ans
  end

  def truthy_answer(ans)
    return false unless ans
    ans = ans.downcase
    case ans
    when 'yes', 'y', 'yep', 'yeah', 'ja', 'si', 'oui'
      true
    else
      false
    end
  end

  private
  
  def record_answer(name, ans)
    var = if name.to_s.include? "@"
      name.to_s
    else
      "@#{name.to_s}"
    end

    instance_variable_set(var, ans)
  end

end


class FileDictionary

  attr_accessor :sha_dictionary, :file_dictionary, :dictionary_path

  MEDIA_TYPES = [:jpg, :jpeg, :png, :gif, :mov, :mp4, :aae]

  def initialize
    @sha_dictionary  = []
    @file_dictionary = []
  end

  def sum_folder(dir)
    files = Dir["#{dir}/**/*.*"]
    open_file_dictionary

    if @sha_dictionary.length < files.reject { |f| f.downcase[@dictionary_path] }.count
      puts "File dictionary is out of date."
      create_file_dictionary(files)
    end

    @file_dictionary = files.map { |f| File.basename(f).upcase }
    @file_dictionary.uniq!
    @sha_dictionary.uniq!
    return @sha_dictionary
  end

  def create_file_dictionary(files)
    print "Creating a dictionary of pre-existing files... "

    @sha_dictionary = files.map do |file|
      File.open(file, 'r') { |f| Digest::SHA256.hexdigest(f.read) }
    end

    write_file_dictionary
  end

  def write_file_dictionary
    File.open(@dictionary_path, "wb+") { |f| f.write @sha_dictionary.join("\n") }
  end

  def open_file_dictionary
    if File.exists?(@dictionary_path)
      @sha_dictionary = File.open(@dictionary_path, "r") { |f| f.read }.split("\n")
    end
  end

end

class Questionnaire

  attr_reader :source_dir, :dest_dir, :file_types, :omit_thumbs

  def initialize(ui)
    @ui = ui
  end

  def ask_questionnaire
    ask_source_dir
    ask_dest_dir
    ask_file_types
    ask_omit_thumbs
    confirmation
  end

  def ask_source_dir
    print "\nI'm going to help get all your pictures and videos together in one place.\nPlease specify a source directory:\n => "
    @source_dir = @ui.get_input(:source_dir)

    while !Dir.exists?(@source_dir)
      print "That doesn't exist. Please enter a valid directory...\n => "
      @source_dir = @ui.get_input
    end

    puts "\nOkay, source directory is #{@source_dir}"
  end

  def ask_dest_dir
    print "\nPlease specify a destination directory:\n => "
    @dest_dir = @ui.get_input('dest_dir')

    while !Dir.exists?(@dest_dir)
      print "\nThat directory doesn't exist.  Please enter a valid destination directory:\n => "
      @dest_dir = @ui.get_input
    end

    print "\nOkay, destination directory is #{@dest_dir}"
  end

  def ask_file_types
    puts "\nHere are the file types I'll be searching for:\n\n ===> #{FileDictionary::MEDIA_TYPES.join(' ')}"
    print "\nWould you like to omit any of these?\nIf yes, enter them now separated by a space. Otherwise, just press enter.\n => "

    omit_types = @ui.get_input
    if omit_types.strip.empty?
      @file_types = FileDictionary::MEDIA_TYPES
    else
      @file_types = FileDictionary::MEDIA_TYPES.reject { |t| omit_types.split(' ').include? t.to_s }
      puts "Here's the new list of file types I'll be searching for:\n\n ===> #{@file_types}"
    end
  end

  def ask_omit_thumbs
    print "\nWould you like to omit thumbnails? (in this case, files under 100KB)\n => "
    @omit_thumbs = @ui.get_input
  end

  def confirmation
    puts "\nNow then, here's whats going to happen:"
    print "I'm going to grab all media files within this and all sub-folders and put them in the destination directory you specified.\nDon't worry about duplicates, I'm smart enough to filter those out :)\nIs all of this okay?\n => "

    ans5 = @ui.get_input
    unless @ui.truthy_answer(ans5)
      puts "Bye!"
      exit 0
    end
  end
end

########## COLLECT OPERATION  PARAMETERS ##########

ui = UserInput.new
q = Questionnaire.new(ui)

q.ask_questionnaire

# grab all files in the source directory and filter out unwanted file types.
omit_thumbs_bool = ui.truthy_answer(q.omit_thumbs)
files = Dir["#{q.source_dir}/**/*.*"]
filtered = files.select { |f| q.file_types.map(&:to_s).include? f.split('.').last.downcase }
filtered.delete_if { |f| f.downcase.include? "thumb" } if omit_thumbs_bool
puts "\nFound #{filtered.count} matching files."

fd = FileDictionary.new
fd.dictionary_path = "#{q.dest_dir}/file-dictionary-dont-touch-me.txt"
fd.sum_folder(q.dest_dir)

print "\nPress enter to begin... "
gets

########## BEGIN #########

written_count = 0
duplicate_count = 0
thumbnail_count = 0
start_time = Time.now

# TODO: add concurrency.
filtered.each_with_index do |file_name|
  File.open(file_name, 'r') do |file|
    sha = Digest::SHA256.hexdigest(file.read)

    unless fd.sha_dictionary.include? sha

      # if the filename already exists in the folder, give it a new name so the old one isn't overwritten.
      if fd.file_dictionary.include? File.basename(file_name).upcase

        existing_file = File.open("#{q.dest_dir}/#{File.basename(file_name)}")

        if file.size < 100000 && omit_thumbs_bool
          puts "skipped thumbnail: #{file_name}"
          thumbnail_count += 1
          next 
        end

        diff = (file.size - existing_file.size).abs

        # if the sha isn't in the dictionary, and the file name is already taken in the destination,
        # and the size differences between the original and the new file are 0B or 100K, then it's
        # safe to assume the two files are the same, skip it.
        if diff == 0 || diff < 100000
          puts "skipped duplicate: #{file_name}"
          duplicate_count += 1
          next
        end

        dest = if existing_file.size < 100000 && file.size > 100000
          # if the existing file is less than 100KB and the new one is larger,
          # the thumbnail was copied before the actual photo. overwrite it with the same name.
          existing_file
        else
          # otherwise, give it a new, unique name.  like the little butterly that it is.
          puts "generating new file name for conflicting file: #{existing_file.path}"
          #unique_name = "#{q.dest_dir}/#{File.basename(file_name, ".*")}-#{Time.now.to_i}#{File.extname(file)}"
          unique_name = "#{q.dest_dir}/#{File.basename(file_name, ".*")}-#{sha}#{File.extname(file)}"
          #sleep 1
          puts unique_name
          unique_name
        end

      else
        basename = File.basename(file_name)
        fd.file_dictionary << basename
        dest = "#{q.dest_dir}/#{basename}"
      end

      fd.sha_dictionary << sha
      FileUtils.cp(file_name, dest, preserve: true)
      puts "copied #{file_name} -> #{dest}"
      written_count += 1

    else
      puts "skipped duplicate: #{file_name}"
      duplicate_count += 1
    end
  end
end

fd.write_file_dictionary

end_time = Time.now

puts "\nDone!"
puts "Wrote #{written_count} files to #{q.dest_dir} in #{(end_time - start_time).round(3)} seconds."
puts "Skipped #{duplicate_count} duplicates, skipped #{thumbnail_count} thumbnails."
