require 'rubygems'
require 'fileutils'
require 'digest'
require 'pry'

def get_input
  ans = gets
  ans.downcase!
  ans.gsub! /\n/, ""
  ans.strip!
  return ans
end

def dotty_output(i)		
  i = i / 100
  i <= @midway ? i.times { print '.' } : (@total_count - i).times { print '.' }		
  puts '.'		
end

def sum_folder(dir)
  print "Creating a dictionary of pre-existing files... "
  files = Dir["#{dir}/*.*"]

  files.each do |file|
    @file_dict << File.basename(file)
    File.open(file, 'r') { |f| @sha_dict << Digest::SHA256.hexdigest(f.read) }
  end

  @file_dict.uniq!
  @sha_dict.uniq!
  puts "done."
end

def truthy_answer(ans)
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

print "\nI'm going to help you organize your pictures. Is that okay? \n => "
ans1 = get_input

unless truthy_answer(ans1)
  puts "K. Later!"
  exit
end

puts "\nCool. You can press Ctrl+C to exit at any time."

print "\nI'm going to process all media files within this and all sub-directories.\nWould you like to specify a source directory?\nEnter the full directory name now, or just press enter to use this one. \n => "
ans2 = get_input
dir = ans2.empty? ? Dir.pwd : ans2

while !Dir.exists?(dir)
  print "That directory doesn't exist. Please enter a valid directory...\n => "
  dir = get_input
  dir = Dir.pwd if dir.empty?
end

puts "\nOkay, using #{dir}"
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
print "I'm going to grab all media files recursively (excluding the ones you specified),\nand then put them in a folder one level up from the target directory.\nDon't worry about duplicates.  I'm smart enough to filter those out :)\nIs all of this okay?\n => "

ans5 = get_input
unless truthy_answer(ans5)
  puts "Bye!"
  exit
end

files = Dir["#{dir}/**/*.*"]
filtered = files.select { |f| media_types.include? f.split('.').last.downcase }
filtered.delete_if { |f| f.downcase.include? "thumb" } if truthy_answer(ans4)
@total_count = filtered.count
puts "\nFound #{@total_count} matching files."

dest_dir = "#{dir}/../Organized\ Pictures"


print "\nPress enter to begin... "
gets

start_time = Time.now

if Dir.exists?(dest_dir)
  sum_folder(dest_dir)
else
  FileUtils.mkdir(dest_dir) 
  puts "Created destination directory."
end

sleep 1
puts "\nWorking!"

@total_count /= 100
@midway = @total_count / 2
written_count = 0
duplicate_count = 0

filtered.each_with_index do |file_name, i|
  dotty_output(i) if i % 100 == 0
  
  File.open(file_name, 'r') do |file|
    sha = Digest::SHA256.hexdigest(file.read)

    unless @sha_dict.include? sha
      # if the filename already exists in the folder, give it a new name so the old
      # one isn't overwritten.
      dest = if @file_dict.include? File.basename(file_name)
        "#{dest_dir}/#{File.basename(file_name, ".*")}-#{Time.now.to_i}#{File.extname(file)}"
      else
        @file_dict << File.basename(file_name)
        dest_dir
      end

      @sha_dict << sha
      FileUtils.cp(file_name, dest, preserve: true)
      written_count += 1
    else
      duplicate_count += 1
    end
  end
end

end_time = Time.now

puts "\nDone!"
puts "Wrote #{written_count} files to #{dest_dir} in #{(end_time - start_time).round(3)} seconds, skipped #{duplicate_count} duplicates."
