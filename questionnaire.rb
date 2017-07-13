require './user_input'
require './media_folder'

class Questionnaire

  attr_reader :source_dir, :dest_dir, :file_types, :omit_thumbs

  include UserInput

  def initialize
  end

  def ask_questionnaire
    ask_source_dir
    ask_dest_dir
    ask_file_types
    # ask_omit_thumbs
    confirmation
  end

  def ask_source_dir
    print "\nI'm going to help get all your pictures and videos together in one place.\nPlease specify a source directory:\n => "
    @source_dir = get_input(:source_dir)
    while !Dir.exists?(@source_dir)
      print "That doesn't exist. Please enter a valid directory...\n => "
      @source_dir = get_input
    end
    puts "\nOkay, source directory is #{@source_dir}"
  end

  def ask_dest_dir
    print "\nPlease specify a destination directory:\n => "
    @dest_dir = get_input('dest_dir')
    while !Dir.exists?(@dest_dir)
      print "\nThat directory doesn't exist.  Please enter a valid destination directory:\n => "
      @dest_dir = get_input
    end
    print "\nOkay, destination directory is #{@dest_dir}"
  end

  def ask_file_types
    puts "\nHere are the file types I'll be searching for:\n\n ===> #{MediaFolder::MEDIA_TYPES.join(' ')}"
    print "\nWould you like to omit any of these?\nIf yes, enter them now separated by a space. Otherwise, just press enter.\n => "
    omit_types = get_input
    if omit_types.strip.empty?
      @file_types = MediaFolder::MEDIA_TYPES
    else
      @file_types = MediaFolder::MEDIA_TYPES.reject { |t| omit_types.split(' ').include? t.to_s }
      puts "Here's the new list of file types I'll be searching for:\n\n ===> #{@file_types}"
    end
  end

  def ask_omit_thumbs
    print "\nWould you like to omit thumbnails? (in this case, files under 100KB)\n => "
    @omit_thumbs = get_input
  end

  def confirmation
    puts "\nNow then, here's whats going to happen:"
    print "I'm going to grab all media files within this and all sub-folders and put them in the destination directory you specified.\nDon't worry about duplicates, I'm smart enough to filter those out :)\nIs all of this okay?\n => "
    ans5 = get_input
    unless truthy_answer(ans5)
      puts "Bye!"
      exit 0
    end
  end
end