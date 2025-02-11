require 'fileutils'
require_relative '../db'

class Model
  class << self
    def setup_table
      err "Subclasses must implement the setup_table method"
      raise NotImplementedError, "Subclasses must implement the setup_table method"
    end

    def db
      @@db ||= begin
        db_file = ENV["NOF_#{$system_name}_DB_FILE"] || File.join(Dir.home, '.nof', "#{$system_name}.db")
        db_dir = File.dirname(db_file)
        FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)
        Database.new(db_file: db_file)
      end
    end

    def delete_db
      @@db.delete
      @@db = nil
    end
  end
end

