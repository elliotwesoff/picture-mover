require 'ostruct'

module OptionsParser

  def parse_options
    options = OpenStruct.new
    ARGV.unshift(' ')
    cli_args = ARGV.join(' ')
    matcher = -> (switch) { /(?<=\s\-#{switch})\s?(\S+)(?=\s\-)?/ }
    s = cli_args.match(matcher.call('s'))
    d = cli_args.match(matcher.call('d'))
    f = cli_args.match(matcher.call('f'))
    b = cli_args.match(matcher.call('b'))
    t = cli_args.match(matcher.call('t'))
    p = cli_args.match(matcher.call('p'))
    v = cli_args.match(matcher.call('v'))
    h = cli_args.match(matcher.call('h'))
    if s && d && !h
      options.source = File.absolute_path(s.captures.first)
      options.destination = File.absolute_path(d.captures.first)
      options.omit_filetypes = f ? f.captures.first.split(";") : []
      options.minimum_size = b ? b.captures.first : 0
      options.preserve_files = p ? true : false
      options.test_run = t ? true : false
      options.verbose = v ? true : false
    else
      puts menu_text
      exit 0
    end
    return options
  end

  def menu_text
    str = <<-MENU
    ruby picture-mover.rb -s [source] -d [destination] [ARGS]
    
    Available switches:
    -s : source directory *
    -d : destination directory *
    -f : omit-filetypes, semicolon delimited
    -b : omit files by size (in bytes)
    -t : test run - don't actually copy any files
    -v : verbose - say all the things
    -h : help - show this message

    * indicates required switch
    Copyright Elliot Wesoff, #{Time.now.year}
    MENU
    return str.split("\n").map(&:strip).join("\n")
  end

end