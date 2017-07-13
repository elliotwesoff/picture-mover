#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'pry'

require './options_parser'
require './media_folder'
require './media_item'
require './image_db'

ARGS = ARGV

class PictureMover

  attr_accessor :options, :written, :duplicate, :thumbnail

  include OptionsParser
  
  def initialize
    @options = parse_options
  end

  def display_stats
  end

  def get_approval
    puts "Press enter to continue..."
    STDIN.getc
  end

  def execute
    image_db = ImageDB.new(options.destination)
    media_folder = MediaFolder.new
    media = media_folder.load_media(options.source)
    written, duplicate, thumbnail = 0, 0, 0
    binding.pry if options.debug
    display_stats
    get_approval
    start = Time.now
    media.each do |file_name|
      file = File.open(file_name, 'r')
      sha = Digest::SHA256.hexdigest(file.read)

      # if the sha is not in the dictionary, merge it into the destination folder.
      # if it is, consider it a duplicate and skip it.
      # http://stackoverflow.com/questions/9333952/case-insensitive-arrayinclude
      unless media_folder.sha_dictionary.any? { |s| s.casecmp(sha) == 0 }

        # if the filename already exists in the folder, give it a new name so the old one isn't overwritten.
        if media_folder.file_dictionary.any? { |f| f.casecmp(File.basename(file_name)) == 0 }

          existing_file = File.open("#{options.destination}/#{File.basename(file_name)}")

          if file.size < options.minimum_size
            puts "file doesn't meet size threshold of #(options.minimum_size}B: #{file_name}" if options.verbose
            thumbnail += 1
            next 
          end

          # if the existing file is less than 100KB and the new one is larger,
          # the thumbnail was copied before the actual photo. overwrite it with the same name.
          # otherwise, give it a new, unique name.  like the little butterly that it is.
          dest = if existing_file.size < 100000 && file.size > 100000
            existing_file
          else
            puts "generating new file name for conflicting file: #{existing_file.path}" if options.verbose
            unique_name = "#{options.destination}/#{File.basename(file_name, ".*")}-#{sha}#{File.extname(file)}"
            puts unique_name
            unique_name
          end

        else
          basename = File.basename(file_name)
          dest = "#{options.destination}/#{basename}"
        end

        FileUtils.cp(file_name, dest, preserve: true, noop: options.test_run)
        MediaItem.persist_item("#{dest}/#{file_name}", sha)
        puts "copied #{file_name} -> #{dest}"
        written += 1

      else # matches the unless.
        puts "skipped duplicate: #{file_name}"
        duplicate += 1
      end
    end

    finish = Time.now

    puts "\nDone!"
    puts "Processed #{media.count} files in #{(finish - start).round(3)} seconds."
    puts "Wrote #{written} new files."
    puts "Skipped #{duplicate} duplicates, skipped #{thumbnail} thumbnails."
  end

end

PictureMover.new.execute