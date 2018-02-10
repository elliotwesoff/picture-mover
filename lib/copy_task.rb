class CopyTask
    attr_accessor :source, :destination, :copy_options, :media_item

    def initialize(opts = {})
      check_options(opts)
      @media_item = opts[:media_item]
      @destination = opts[:destination]
      @copy_options = opts[:copy_options] || {}
      @source = media_item.file_path
    end

    def file_name
      return File.basename(source)
    end

    def copy!
      FileUtils.cp(source, destination, copy_options) 
    end

    private
    
    def check_options(opts = {})
      errors = []
      errors << "#{self.class} must be given a MediaItem instance for instantiation." unless opts[:media_item]
      errors << "#{self.class} must be given a destination path for instantiation." unless opts[:destination]
      raise errors.join(",") if errors.any?
    end

end