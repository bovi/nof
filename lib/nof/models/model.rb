require 'fileutils'
require_relative '../db'

class Model
  class << self
    def setup_tables
      err "Subclasses must implement the setup_table method"
      raise NotImplementedError, "Subclasses must implement the setup_table method"
    end

    def setup_all_tables
      ObjectSpace.each_object(Class).select do |c|
        c < Model
      end.each do |model|
        model.setup_tables
      end
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

    def create_table(name, columns)
      db.execute("CREATE TABLE IF NOT EXISTS #{name} (#{columns.join(', ')})")
    end
  
    def count(table)
      db.execute("SELECT COUNT(*) AS cnt FROM #{table}").first['cnt']
    end

    def sanitize_uuid(uuid)
      raise ArgumentError, "UUID is required" unless uuid
      raise ArgumentError, "Invalid UUID format" unless uuid.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      uuid
    end

    def transform_row(row)
      row['opts'] = JSON.parse(row['opts']) if row && row['opts']
      row
    end
  end
end

