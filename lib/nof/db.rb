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

  def with_transaction(&block)
    with_connection do |conn|
      conn.transaction do 
        block.call(conn)
      end
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

  def execute(sql, *args)
    @pool.with_connection do |conn|
      conn.execute(sql, args) 
    end
  end

  def with_transaction(&block)
    @pool.with_transaction do |conn|
      block.call(conn)
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
