require 'rubygems'
require 'fileutils'
require 'digest'
require 'pry'

def get_input
  ans = gets
  ans.downcase!
  ans.chomp!
  ans.strip!
  # handle backslashes properly for windows and linux paths.
  ans[0...2].match(/[A-Z]:/i) ? ans.gsub!(/\\/, "/") : ans.gsub!(/\\/, "")
  return ans
end

def sum_folder(dir)
  files = Dir["#{dir}/**/*.*"]

  summer = -> do
    if files.length > 0
      print "Creating a dictionary of pre-existing files... "

      @sha_dict = files.map do |file|
        File.open(file, 'r') { |f| Digest::SHA256.hexdigest(f.read) }
      end

      write_file_dictionary
    end
  end

  if File.exists?(@dict_path)
    shas = File.open(@dict_path, "r") { |f| f.read }
    @sha_dict = shas.split("\n")
    if @sha_dict.length < files.reject { |f| f.downcase[@dict_path] }.count
      puts "File dictionary is out of date."
      summer.call
    end
  else
    summer.call
  end

  @file_dict = files.map { |f| File.basename(f).upcase }
  @file_dict.uniq!
  @sha_dict.uniq!
end

def write_file_dictionary
  File.open(@dict_path, "wb+") { |f| f.write @sha_dict.join("\n") }
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

########## BEGIN SCRIPT ##########

@file_dict, @sha_dict = [], []
media_types = ['jpg', 'jpeg', 'png', 'gif', 'mov', 'mp4', 'aae']

print "Hello! \n => "
greeting = get_input
puts "\nYou could at least say hi..." if greeting.empty?

print "\nI'm going to process all media files within a source directory.\nPlease enter a source directory now:\n => "
source_dir = get_input

while !Dir.exists?(source_dir)
  print "That doesn't exist. Please enter a valid directory...\n => "
  source_dir = get_input
end

puts "\nOkay, source directory is #{source_dir}"

print "\nPlease specify a destination directory, or just press enter to use one above the source directory (#{File.absolute_path("#{source_dir}/..")})\n => "
dest_dir = get_input

if dest_dir.empty?
  one_up = File.absolute_path("#{source_dir}/..")
  dest_dir = "#{one_up}/Organized Media"
  FileUtils.mkdir_p(dest_dir)
else
  while !Dir.exists?(dest_dir)
    print "\nThat directory doesn't exist.  Please enter a valid destination directory:\n => "
    dest_dir = get_input
  end
end

print "\nOkay, destination directory is #{dest_dir}"

puts "\nHere are the file types I'll be searching for:\n\n ===> #{media_types.join(' ')}"
print "\nWould you like to omit any of these?\nIf yes, enter them now separated by a space. Otherwise, just press enter.\n => "

omit_types = get_input
unless omit_types.empty?
  omit_types.split(' ').each { |f| media_types.delete f }
  puts "Here's the new list of file types I'll be searching for:\n\n ===> #{media_types.join(' ')}"
end

print "\nWould you like to omit thumbnails? (in this case, files under 100KB)\n => "
omit_thumbs = get_input

puts "\nNow then, here's whats going to happen:"
print "I'm going to grab all media files within this and all sub-folders and put them in the destination directory you specified.\nDon't worry about duplicates, I'm smart enough to filter those out :)\nIs all of this okay?\n => "

ans5 = get_input
unless truthy_answer(ans5)
  puts "Bye!"
  exit
end

# grab all files in the source directory and filter out unwanted file types.
files = Dir["#{source_dir}/**/*.*"]
filtered = files.select { |f| media_types.include? f.split('.').last.downcase }
filtered.delete_if { |f| f.downcase.include? "thumb" } if truthy_answer(omit_thumbs)
@total_count = filtered.count
puts "\nFound #{@total_count} matching files."

@dict_path = "#{dest_dir}/file_dictionary-do_not_alter.txt"
sum_folder(dest_dir)


print "\nPress enter to begin... "
gets

start_time = Time.now

sleep 1
puts "\nWorking!"

@total_count /= 100
@midway = @total_count / 2
written_count = 0
duplicate_count = 0
thumbnail_count = 0
omit_thumbs_bool = truthy_answer(omit_thumbs)

########## DO THE DAMN THING! #########

filtered.each_with_index do |file_name|
  File.open(file_name, 'r') do |file|
    sha = Digest::SHA256.hexdigest(file.read)

    unless @sha_dict.include? sha

      # if the filename already exists in the folder, give it a new name so the old one isn't overwritten.
      if @file_dict.include? File.basename(file_name).upcase

        existing_file = File.open("#{dest_dir}/#{File.basename(file_name)}")

        if file.size < 100000 && omit_thumbs_bool
          puts "skipped thumbnail: #{file_name}"
          thumbnail_count += 1
          next 
        end

        diff = (file.size - existing_file.size).abs

        if diff == 0 || diff < 100000 # they're the same god damn file.
          puts "skipped duplicate: #{file_name}"
          next
        end

        dest = if existing_file.size < 100000 && file.size > 100000
          # if the existing file is less than 100KB and the new one is larger,
          # the thumbnail was copied before the actual photo. overwrite it with the same name.
          dest_dir
        else
          # otherwise, give it a new, unique name.  like the little butterly that it is.
          "#{dest_dir}/#{File.basename(file_name, ".*")}-#{Time.now.to_i}#{File.extname(file)}"
        end

      else
        @file_dict << File.basename(file_name)
        dest = dest_dir
      end

      @sha_dict << sha
      FileUtils.cp(file_name, dest, preserve: true)
      puts "copied #{file_name}"
      written_count += 1

    else
      puts "skipped duplicate: #{file_name}"
      duplicate_count += 1
    end
  end
end

write_file_dictionary

end_time = Time.now

puts "\nDone!"
puts "Wrote #{written_count} files to #{dest_dir} in #{(end_time - start_time).round(3)} seconds."
puts "Skipped #{duplicate_count} duplicates, skipped #{thumbnail_count} thumbnails."
