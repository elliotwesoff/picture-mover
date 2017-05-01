require 'rubygems'
require 'fileutils'
require 'pry'

require './questionnaire'
require './user_input'
require './media_folder'
require './media_item'
require './image_db'

ui = UserInput.new
q = Questionnaire.new(ui)
q.ask_questionnaire
ImageDB.new(q.dest_dir.to_s) # initialize database.
media_folder = MediaFolder.new
media_folder.load_media(q.dest_dir.to_s)

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

    # if the sha is not in the dictionary, merge it into the destination folder.
    # if it is, consider it a duplicate and skip it.
    unless fd.sha_dictionary.include? sha

      # if the filename already exists in the folder, give it a new name so the old one isn't overwritten.
      if fd.file_dictionary.include? File.basename(file_name).upcase

        existing_file = File.open("#{q.dest_dir}/#{File.basename(file_name)}")

        # if file is less than 100K, and the user chose to skip thumbs, consider it a thumb and skip it.
        if file.size < 100000 && omit_thumbs_bool
          puts "skipped thumbnail: #{file_name}"
          thumbnail_count += 1
          next 
        end

        # if the sha isn't in the dictionary, and the file name is already taken in the destination,
        # and the size differences between the original and the new file are 0B or 100K, then it's
        # safe to assume the two files are the same, skip it.
        diff = (file.size - existing_file.size).abs
        if diff == 0 || diff < 100000
          puts "skipped duplicate: #{file_name}"
          duplicate_count += 1
          next
        end

        # if the existing file is less than 100KB and the new one is larger,
        # the thumbnail was copied before the actual photo. overwrite it with the same name.
        # otherwise, give it a new, unique name.  like the little butterly that it is.
        dest = if existing_file.size < 100000 && file.size > 100000
          existing_file
        else
          puts "generating new file name for conflicting file: #{existing_file.path}"
          unique_name = "#{q.dest_dir}/#{File.basename(file_name, ".*")}-#{sha}#{File.extname(file)}"
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

    else # matches the unless.
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
