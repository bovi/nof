require 'sqlite3'
require 'thread'

class ConnectionPool
  def initialize(size: 5, db_file:)
    @size = size
    @db_file = db_file
    @pool = Queue.new
    @size.times { 
      conn = SQLite3::Database.new(@db_file)
      # Configure connection for better concurrency handling
      conn.busy_timeout = 5000  # 5 second timeout
      conn.execute("PRAGMA journal_mode = WAL")  # Write-Ahead Logging for better concurrency
      conn.execute("PRAGMA busy_timeout = 5000")
      # Configure result handling
      conn.results_as_hash = true  # Return results as hashes instead of arrays
      conn.type_translation = true # Translate SQLite types to Ruby types
      @pool << conn
    }
  end

  # Provides a connection to the block and then returns it to the pool.
  def with_connection(&block)
    conn = @pool.pop
    begin
      block.call(conn)
    ensure
      @pool << conn
    end
  end

  # Closes all connections in the pool.
  def shutdown
    until @pool.empty?
      conn = @pool.pop(true) rescue nil
      conn&.close
    end
  end
end

class Database
  def initialize(db_file: nil)
    if db_file.nil?
      err "db_file is required"
      raise ArgumentError, "db_file is required"
    end
    @db_file = db_file
    @pool = ConnectionPool.new(size: 5, db_file: db_file)
  end

  def create_table(name, columns)
    @pool.with_connection do |conn|
      conn.execute("CREATE TABLE IF NOT EXISTS #{name} (#{columns.join(', ')})")
    end
  end

  def count(table)
    @pool.with_connection do |conn|
      conn.execute("SELECT COUNT(*) AS cnt FROM #{table}").first['cnt']
    end
  end

  def execute(sql, *args)
    debug "execute: #{sql}, #{args.inspect}"
    @pool.with_connection do |conn|
      case args.size
      when 0
        conn.execute(sql)
      when 1
        conn.execute(sql, args[0])
      else
        conn.execute(sql, *args) 
      end
    end
  end

  def close
    @pool.shutdown
  end

  def delete
    close
    File.delete(@db_file)
  end
end
