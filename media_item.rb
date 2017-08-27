require 'active_record'
require 'digest'


class MediaItem

  attr_accessor :file_path, :sha256, :persist

  def initialize(_file_path, _persist = false)
    @file_path = _file_path
    @persist = _persist
    calculate_sha
  end

  def calculate_sha
    @sha256 ||= Digest::SHA256.hexdigest(File.open(file_path).read)
  end

  def self.persist_item(path, sha = nil)
    # DEPRECATED : implementation elsewhere should be changed so this method doesn't need to exist.
    return "DEPRECATED: MediaItem.persist_item"
    mi = self.new(path)
    self.find_or_create_by(file_name: mi.name, sha256: mi.sha256)
  end
  
end