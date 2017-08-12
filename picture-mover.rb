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

  def main
    eval("execute_#{options.copy_method}")
  end

  def get_approval
    puts "Press enter to continue ..."
    STDIN.getc
  end

  def execute_1
    image_db = ImageDB.new(options.destination)
    media_folder = MediaFolder.new
    media = media_folder.load_media(options.source)
    written, duplicate, skipped = 0, 0, 0
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

  def execute_2
    # 1. build a collection of all entries in the source and the destination with data shape:
    #    { path: string, sha256: string }
    #
    # 2. discard all items in the source that have sha256 hashes that exist in the destination -
    #    those files unquestionably already exist there.
    # 
    # 3. build destination paths for all of the files in the source folder, and rename the files
    #    to the hash value if the file namem already exists in the destination.
    # 
    # 4. make sure the user is aware of the details of the copy process, get their approval, and
    #    begin the copy process. specific instructions on the copy should be determined by the
    #    user based on selected options via CLI, or if not specified, by their defaults.

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
    items = requested.library.dup
    existing_hashes = existing.library.map { |f| f[:sha256] }
    existing_names = existing.library.map { |f| File.basename(f[:path]) }
    items.reject! { |x| existing_hashes.include?(x[:sha256]) }
    items.each { |x| x[:destination] = "#{options.destination}/#{File.basename(x[:path])}" }
    items.select { |x| existing_names.include?(File.basename(x[:path])) }.each do |file|
      file[:destination] = "#{file[:sha256]}#{File.extname(file[:path])}"
    end
    puts "Copying #{items.count}/#{requested.library.count} items..."
    get_approval
    items.each do |file|
      Thread.new { FileUtils.cp(file[:path], file[:destination], copy_options) }.join
    end
  end

  private

  def method_missing(m, *args, &block)
    puts "\nERROR: Unknown copy process name: #{m.to_s.gsub(/[^\d]/, '')}"
    puts
    puts menu_text
  end

  def log(str)
    # TODO
    puts str
  end

end

begin
  pm = PictureMover.new
  pm.main
  exit 0
rescue => e
  if pm && pm.log
    pm.log.write e.message
    pm.log.write e.backtrace.join("\n")
  end
  puts "FATAL: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end
