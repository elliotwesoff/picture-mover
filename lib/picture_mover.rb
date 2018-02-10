#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'pry'

require './options_parser'
require './media_folder'
require './media_item'
require './image_db'
require './copy_task'

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
    puts "Press enter to continue."
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

    requested = MediaFolder.new(options.source, options)
    existing = MediaFolder.new(options.destination, options)
    a = Thread.new { 
      existing.load_media
      existing.build_library
      existing.filter_duplicates
      existing.rename_conflicting_files
    }
    b = Thread.new {
      requested.load_media
      requested.build_library
      requested.filter_duplicates
      requested.rename_conflicting_files
    }
    [a, b].map(&:join) # wait for the threaded processes to finish.
    items = requested.library.dup
    items.reject! { |x| existing.sha_dictionary.include?(x.sha256) }
    copy_tasks = items.map do |x|
      CopyTask.new({
        media_item: x,
        destination: "#{options.destination}/#{File.basename(x.file_path)}",
        copy_options: copy_options
      })
    end
    existing_names = existing.library.map { |x| File.basename(x.file_path) }
    existing_names_regex = Regexp.new(existing_names.map { |x| "(^#{x}$)" }.join('|'), i)
    copy_tasks.each do |ct|
      while existing_names_regex.match(File.basename(ct.destination))
        ct.destination = "#{File.dirname(ct.destination)}/#{Digest::SHA256.hexdigest(Time.now.to_s)}#{File.extname(ct.source)}"
      end
    end
    puts "Copying #{copy_tasks.count} items..."
    get_approval
    copy_tasks.each(&:copy!)
  end

  private

  def method_missing(m, *args, &block)
    puts "\nERROR: Unknown copy process name: #{m.to_s.gsub(/execute_/, '')}"
    puts
    sleep 1
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
