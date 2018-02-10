require 'sqlite3'

class ImageDB

    attr_accessor :source

    def initialize(source_dir)
      @source = source_dir
      ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: "#{@source}/images.db")

      unless ActiveRecord::Base.connection.data_source_exists? 'media_items'
        ActiveRecord::Schema.define do
          create_table :media_items do |t|
            t.string :file_name
            t.string :sha256
          end
        end
      end
    end

end