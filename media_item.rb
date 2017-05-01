require 'active_record'
require 'digest'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: "#{@source}/images.db")


class MediaItem < ActiveRecord::Base

  def self.persist_item(path, sha = nil)
      name = File.basename(path)
      sha = Digest::SHA256.hexdigest(File.open(path, 'r').read) unless sha
      self.find_or_create_by(file_name: name, sha256: sha)
  end
  
end