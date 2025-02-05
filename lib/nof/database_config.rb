require 'sqlite3'

module NOF
  module DatabaseConfig
    def db_path
      @db_path ||= File.join(CONFIG_DIR, 'nof.db')
    end

    def db
      Thread.current[:nof_db] ||= begin
        log("Using database at: #{db_path}")
        db = SQLite3::Database.new(db_path)
        # Enable WAL mode for better concurrency
        db.execute("PRAGMA journal_mode=WAL")
        # Enable foreign keys
        db.execute("PRAGMA foreign_keys=ON")
        db
      end
    end

    def setup_tables!
      return unless respond_to?(:setup_tables)
      setup_tables(db)
    end

    def self.setup_all_tables!
      # Find all classes that extend DatabaseConfig
      Object.constants
        .map { |const| Object.const_get(const) }
        .select { |const| const.is_a?(Class) && const.singleton_class.include?(DatabaseConfig) }
        .each(&:setup_tables!)
    end

    def close_db
      if Thread.current[:nof_db]
        Thread.current[:nof_db].close
        Thread.current[:nof_db] = nil
      end
    end

    def self.close_all_connections
      Thread.list.each do |thread|
        if thread[:nof_db]
          thread[:nof_db].close rescue nil
          thread[:nof_db] = nil
        end
      end
    end
  end
end 