class TestDB < Minitest::Test
    def setup
      # Create a temporary database file in the system temp directory
      @db_file = File.join(Dir.tmpdir, "test_config.db")
      FileUtils.rm_f(@db_file)  # Remove if it exists from a previous run
  
      # Create the database and set up a simple table
      @db = SQLite3::Database.new(@db_file)
      @db.execute <<-SQL
        CREATE TABLE configuration (
          id INTEGER PRIMARY KEY,
          value TEXT
        );
      SQL
      @db.execute("INSERT INTO configuration (value) VALUES ('test_value')")
  
      # Initialize the connection pool with a few connections
      @pool = ConnectionPool.new(size: 3, db_file: @db_file)
    end
  
    def teardown
      # Ensure that connections are closed and the temporary file is removed
      @pool.shutdown
      @db.close if @db
      FileUtils.rm_f(@db_file)
    end
  
    def test_single_thread_query
      # Test that a single thread can retrieve the configuration value
      @pool.with_connection do |conn|
        result = conn.execute("SELECT value FROM configuration")
        assert_equal "test_value", result.first['value']
      end
    end
  
    def test_multiple_thread_query
      # Test that multiple threads can concurrently get connections and query the DB
      results = []
      threads = 5.times.map do
        Thread.new do
          @pool.with_connection do |conn|
            res = conn.execute("SELECT value FROM configuration")
            # Append the result to the shared array
            results << res.first['value']
          end
        end
      end
      threads.each(&:join)
  
      # Verify that each thread got the expected result
      assert_equal 5, results.size
      results.each do |value|
        assert_equal "test_value", value
      end
    end

    def test_write_operation
      # Test that write operations work correctly through the connection pool
      @pool.with_connection do |conn|
        conn.execute("INSERT INTO configuration (value) VALUES ('new_value')")
      end

      # Verify the write was successful by reading it back
      @pool.with_connection do |conn|
        result = conn.execute("SELECT value FROM configuration WHERE value = 'new_value'")
        assert_equal "new_value", result.first['value']
      end
    end

    def test_concurrent_write_operations
      # Test multiple threads can write concurrently
      threads = 3.times.map do |i|
        Thread.new do
          @pool.with_connection do |conn|
            conn.execute("INSERT INTO configuration (value) VALUES (?)", "thread_value_#{i}")
          end
        end
      end
      threads.each(&:join)

      # Verify all writes were successful
      @pool.with_connection do |conn|
        result = conn.execute("SELECT COUNT(*) AS cnt FROM configuration WHERE value LIKE 'thread_value_%'")
        assert_equal 3, result.first['cnt']
      end
    end

    def test_parallel_read_write_operations
      # Test concurrent reads and writes
      read_results = []
      write_count = 5

      # Create threads that will both read and write
      threads = write_count.times.map do |i|
        Thread.new do
          # Do a write operation
          @pool.with_connection do |conn|
            conn.execute("INSERT INTO configuration (value) VALUES (?)", "parallel_value_#{i}")
          end

          # Do a read operation
          @pool.with_connection do |conn|
            res = conn.execute("SELECT value FROM configuration WHERE value = ?", "parallel_value_#{i}")
            read_results << res.first['value']
          end
        end
      end
      threads.each(&:join)

      # Verify all writes were successful and could be read back
      assert_equal write_count, read_results.size
      write_count.times do |i|
        assert_includes read_results, "parallel_value_#{i}"
      end

      # Verify total count in database
      @pool.with_connection do |conn|
        result = conn.execute("SELECT COUNT(*) AS cnt FROM configuration WHERE value LIKE 'parallel_value_%'")
        assert_equal write_count, result.first['cnt']
      end
    end

    def test_connection_pool_under_stress
      # Test the connection pool under heavy load
      num_threads = 20
      operations_per_thread = 50
      total_operations = num_threads * operations_per_thread
      
      threads = num_threads.times.map do |thread_id|
        Thread.new do
          operations_per_thread.times do |op_id|
            # Alternate between reads and writes
            if op_id.even?
              @pool.with_connection do |conn|
                conn.execute("INSERT INTO configuration (value) VALUES (?)", 
                           "stress_test_#{thread_id}_#{op_id}")
              end
            else
              @pool.with_connection do |conn|
                conn.execute("SELECT COUNT(*) FROM configuration WHERE value LIKE 'stress_test_%'")
              end
            end
          end
        end
      end

      threads.each(&:join)

      # Verify the expected number of writes occurred
      @pool.with_connection do |conn|
        result = conn.execute("SELECT COUNT(*) AS cnt FROM configuration WHERE value LIKE 'stress_test_%'")
        expected_writes = total_operations / 2 # Half of operations were writes
        assert_equal expected_writes, result.first['cnt']
      end
    end
  end