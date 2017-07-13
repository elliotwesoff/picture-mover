require 'rubygems'
require 'fileutils'
require 'pry'

require './questionnaire'
require './media_folder'
require './media_item'
require './image_db'


class PictureMover

  attr_accessor :written, :duplicate, :thumbnail, :start, :finish, :questionnaire, :media_folder, :image_db, :media
  
  def initialize
    @questionnaire = Questionnaire.new
    @written   = 0
    @duplicate = 0
    @thumbnail = 0
  end

  def execute
    @questionnaire.ask_questionnaire
    @image_db = ImageDB.new(q.dest_dir.to_s)
    @media_folder = MediaFolder.new
    @media = @media_folder.load_media(q.source_dir)
    print "\nPress enter to begin... "; gets
    @start = Time.now
    @media.each do |file_name|
      file = File.open(file_name, 'r')
      sha = Digest::SHA256.hexdigest(file.read)

      # if the sha is not in the dictionary, merge it into the destination folder.
      # if it is, consider it a duplicate and skip it.
      # http://stackoverflow.com/questions/9333952/case-insensitive-arrayinclude
      unless @media_folder.sha_dictionary.any? { |s| s.casecmp(sha) == 0 }

        # if the filename already exists in the folder, give it a new name so the old one isn't overwritten.
        if @media_folder.file_dictionary.any? { |f| f.casecmp(File.basename(file_name)) == 0 }

          existing_file = File.open("#{q.dest_dir}/#{File.basename(file_name)}")

          # if file is less than 100K, and the user chose to skip thumbs, consider it a thumb and skip it.
          if file.size < 100000
            puts "skipped thumbnail: #{file_name}"
            @thumbnail += 1
            next 
          end

          # if the sha isn't in the dictionary, and the file name is already taken in the destination,
          # and the size differences between the original and the new file are 0B or 100K, then it's
          # safe to assume the two files are the same, skip it.
          diff = (file.size - existing_file.size).abs
          if diff == 0 || diff < 100000
            puts "skipped duplicate: #{file_name}"
            @duplicate += 1
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
          dest = "#{q.dest_dir}/#{basename}"
        end

        FileUtils.cp(file_name, dest, preserve: true)
        MediaItem.persist_item("#{dest}/#{file_name}", sha)
        puts "copied #{file_name} -> #{dest}"
        @written += 1

      else # matches the unless.
        puts "skipped duplicate: #{file_name}"
        @duplicate += 1
      end
    end

    @finish = Time.now
    
    puts "\nDone!"
    puts "Processed #{@media.count} files in #{(@finish - @start).round(3)} seconds."
    puts "Wrote #{@written} new files."
    puts "Skipped #{@duplicate} duplicates, skipped #{@thumbnail} thumbnails."
  end
end
