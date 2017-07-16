#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'pry'

require './options_parser'
require './media_folder'
require './media_item'
require './image_db'

class PictureMover

  attr_accessor :options, :written, :duplicate, :skipped, :copy_options

  include OptionsParser
  
  def initialize
    @options = parse_options
    @copy_options = { 
      preserve: options.preserve_files,
      noop: options.test_run,
      verbose: options.verbose
    }
  end

  def display_stats
  end

  def get_approval
    puts "Press enter to continue..."
    STDIN.getc
  end

  def execute_2
    existing = MediaFolder.new(options.destination)
    requested = MediaFolder.new(options.source)
    a = Thread.new { 
      existing.load_media
      existing.build_library
    }
    b = Thread.new {
      requested.load_media
      requested.build_library
    }
    [a, b].map(&:join) # wait for the threaded processes to finish.
    binding.pry
  end

  def execute_1
    image_db = ImageDB.new(options.destination)
    media_folder = MediaFolder.new
    media = media_folder.load_media(options.source)
    written, duplicate, skipped = 0, 0, 0
    display_stats
    # get_approval
    start = Time.now
    media.each do |file_name|
      file = File.open(file_name, 'r')
      raw = file.read

      if file.size < options.minimum_size
        puts "file doesn't meet size threshold of #(options.minimum_size}B: #{file_name}" if options.verbose
        skipped += 1
        next 
      end

      sha256 = Digest::SHA256.hexdigest(raw)

      # http://stackoverflow.com/questions/9333952/case-insensitive-arrayinclude
      if media_folder.sha256_dictionary.any? { |s| s.casecmp(sha256) == 0 }
        puts "skipped duplicate: #{file_name}"
        duplicate += 1
        skipped += 1
      else
        new_file_path = "#{options.destination}/#{File.basename(file_name)}"
        if media_folder.file_dictionary.any? { |f| f.casecmp(File.basename(file_name)) == 0 }
          new_file_path = "#{options.destination}/#{File.basename(file_name, ".*")}-#{Digest::SHA1.hexdigest(raw)}#{File.extname(file)}"
          puts "generated new file name for conflicting file: #{existing_file.path}\n#{new_file_path}" if options.verbose
        end
        FileUtils.cp(file_name, new_file_path, copy_options)
        MediaItem.persist_item("#{options.destination}/#{file_name}", sha256)
        puts "copied #{file_name} -> #{new_file_path}"
        written += 1
      end
    end

    finish = Time.now

    puts "\nDone!"
    puts "Processed #{media.count} files in #{(finish - start).round(3)} seconds."
    puts "Wrote #{written} new files."
    puts "Skipped #{duplicate} duplicates, #{skipped} files skipped in total."
  end

end

PictureMover.new.execute_2