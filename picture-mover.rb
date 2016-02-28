require 'rubygems'
require 'fileutils'
require 'digest'
require 'pry'

def get_input
  ans = gets
  ans.downcase!
  ans.gsub! /\n/, ""

  # handle backslashes properly for windows and linux paths.
  ans[0...2].match(/[A-Z]:/i) ? ans.gsub!(/\\/, "/") : ans.gsub!(/\\/, "")
  ans.strip!
  return ans
end

def sum_folder(dir)
  files = Dir["#{dir}/**/*.*"]
  dict_path = "#{dir}/file_dictionary-do_not_alter.txt"

  summer = -> do
    if files.length > 0
      print "Creating a dictionary of pre-existing files... "

      @sha_dict = files.map do |file|
        File.open(file, 'r') { |f| Digest::SHA256.hexdigest(f.read) }
      end

      write_file_dictionary(dir)
    end
  end

  if File.exists?(dict_path)
    shas = File.open(dict_path, "r") { |f| f.read }
    @sha_dict = shas.split("\n")
    summer.call if @sha_dict.length < files.length
  else
    summer.call
  end

  @file_dict = files.map { |f| File.basename(f).upcase }
  @file_dict.uniq!
  @sha_dict.uniq!
end

def write_file_dictionary(dir)
  dict_path = "#{dir}/file_dictionary-do_not_alter.txt"
  File.open(dict_path, "wb+") { |f| f.write @sha_dict.join("\n") }
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

print "\nI'm going to process all media files within this and all sub-directories.\nWould you like to specify a source directory?\nEnter the full directory name now, or just press enter to use this one. \n => "
ans2 = get_input
dir = ans2.empty? ? Dir.pwd : ans2

while !Dir.exists?(dir)
  print "That directory doesn't exist. Please enter a valid directory...\n => "
  dir = get_input
  dir = Dir.pwd if dir.empty?
end

puts "\nOkay, using #{dir}"

print "\nPlease specify a destination directory, or just press enter to use one above the current directory (#{File.absolute_path("#{Dir.pwd}/..")})\n => "
dest_dir = get_input
if dest_dir.empty?
  print "\nOkay, using #{dest_dir}"
else
  while !Dir.exists?(dest_dir)
    print "\nThat directory doesn't exist.  Please enter a valid destination directory:\n => "
    dest_dir = get_input
  end
end

puts "\nHere are the file types I'll be searching for:\n\n ===> #{media_types.join(' ')}"
print "\nWould you like to omit any of these?\nIf yes, enter them now separated by a space. Otherwise, just press enter.\n => "

ans3 = get_input
unless ans3.empty?
  ans3.split(' ').each { |f| media_types.delete f }
  puts "Here's the new list of file types I'll be searching for:\n\n ===> #{media_types.join(' ')}"
end

print "\nWould you like to omit thumbnails?\n => "
ans4 = get_input

puts "\nNow then, here's whats going to happen:"
print "I'm going to grab all media files recursively (excluding the ones you specified),\nand put them in the folder you specified.\nDon't worry about duplicates.  I'm smart enough to filter those out :)\nIs all of this okay?\n => "

ans5 = get_input
unless truthy_answer(ans5)
  puts "Bye!"
  exit
end

# grab all files in the source directory and filter out unwanted file types.
files = Dir["#{dir}/**/*.*"]
filtered = files.select { |f| media_types.include? f.split('.').last.downcase }
filtered.delete_if { |f| f.downcase.include? "thumb" } if truthy_answer(ans4)
@total_count = filtered.count
puts "\nFound #{@total_count} matching files."

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

filtered.each_with_index do |file_name, i|
  
  File.open(file_name, 'r') do |file|
    sha = Digest::SHA256.hexdigest(file.read)

    unless @sha_dict.include? sha

      # if the filename already exists in the folder, give it a new name so the old one isn't overwritten.
      if @file_dict.include? File.basename(file_name).upcase
        existing_file = File.open("#{dest_dir}/#{File.basename(file_name)}")

        if file.size < 100000 && truthy_answer(ans4)
          puts "skipped thumbnail: #{file_name}"
          thumbnail_count += 1
          next 
        end

        diff = (file.size - existing_file.size).abs
        next if diff == 0 || diff < 100000 # they're the same god damn file.

        dest = if existing_file.size < 100000 && file.size > 100000
          # if the existing file is less than 100KB and the new one is larger,
          # the thumbnail was copied before the actual photo. overwrite it with the same name.
          dest_dir
        else
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
      duplicate_count += 1
    end
  end
end

print "Updating file dictionary... "
write_file_dictionary(dest_dir)

end_time = Time.now

puts "\nDone!"
puts "Wrote #{written_count} files to #{dest_dir} in #{(end_time - start_time).round(3)} seconds."
puts "Skipped #{duplicate_count} duplicates, #{thumbnail_count} thumbnails."
