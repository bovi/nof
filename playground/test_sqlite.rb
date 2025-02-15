require 'sqlite3'
require 'benchmark'

def explain_query(db, query, params = [])
    puts "\nEXPLAIN QUERY PLAN for: #{query}"
    plan = db.execute("EXPLAIN QUERY PLAN " + query, params)
    plan.each do |row|
        puts "#{row[0]}|#{row[1]}|#{row[2]}|#{row[3]}"
    end
    puts
end

def perform_test(test_name, db_structure)
    puts "\nTest Name: #{test_name}"
    puts "=" * 50

    # Delete old database file if it exists
    File.delete('test.db') if File.exist?('test.db')

    # Open a database
    db = SQLite3::Database.new 'test.db'
    
    # Enable foreign keys and set some performance parameters
    db.execute "PRAGMA foreign_keys = ON"
    db.execute "PRAGMA cache_size = -2000000" # 2GB cache
    db.execute "PRAGMA journal_mode = WAL"
    db.execute "PRAGMA synchronous = NORMAL"

    # Create a table
    db.execute db_structure

    print "Writing #{test_name}: "

    # Generate more realistic time series data
    # We'll create 50 sensors (keys) each reporting every minute for 30 days
    num_sensors = 50
    interval = 60  # 1 reading per minute
    duration = 86400 * 30  # 30 days
    base_time = Time.now.to_i - duration
    
    write_time = Benchmark.measure do
        db.transaction do
            num_sensors.times do |sensor_id|
                # Each sensor will have slightly different patterns
                base_value = rand(100)
                amplitude = rand(20)
                noise = rand(5)
                
                # Generate one reading per minute for the entire duration
                (0..duration).step(interval) do |offset|
                    ts = base_time + offset
                    # Create a somewhat cyclical pattern with noise
                    hour_of_day = Time.at(ts).hour
                    day_factor = Math.sin(hour_of_day * Math::PI / 12)  # Daily cycle
                    value = base_value + (amplitude * day_factor) + rand(-noise..noise)
                    
                    db.execute(
                        "INSERT INTO data (key, value, ts) VALUES (?, ?, ?)",
                        [sensor_id, value.round, ts]
                    )
                end
            end
        end
    end
    puts write_time

    # Analyze to update statistics for query planner
    db.execute "ANALYZE"

    # Get some sample timestamps for our queries
    sample_ts = db.execute("SELECT ts FROM data LIMIT 1")[0][0]
    sample_key = rand(num_sensors)

    print "Recent point query by sensor: "
    point_query = "SELECT * FROM data WHERE key = ? ORDER BY ts DESC LIMIT 1"
    explain_query(db, point_query, [sample_key])
    point_time = Benchmark.measure do
        1000.times do
            key = rand(num_sensors)
            db.execute(point_query, [key])
        end
    end
    puts point_time

    print "Small time window for one sensor: "
    sensor_window_query = "SELECT * FROM data WHERE key = ? AND ts BETWEEN ? AND ? ORDER BY ts"
    window_start = sample_ts
    window_end = window_start + 3600  # 1 hour of data
    explain_query(db, sensor_window_query, [sample_key, window_start, window_end])
    window_time = Benchmark.measure do
        200.times do
            key = rand(num_sensors)
            start_ts = base_time + rand(duration - 3600)
            db.execute(sensor_window_query, [key, start_ts, start_ts + 3600])
        end
    end
    puts window_time

    print "Last hour across all sensors: "
    last_hour_query = "SELECT * FROM data WHERE ts > ? ORDER BY ts"
    last_hour_start = base_time + duration - 3600
    explain_query(db, last_hour_query, [last_hour_start])
    last_hour_time = Benchmark.measure do
        50.times do
            start_ts = base_time + rand(duration - 3600)
            db.execute(last_hour_query, [start_ts])
        end
    end
    puts last_hour_time

    print "Hourly averages for one sensor: "
    hourly_avg_query = """
        SELECT 
            (ts / 3600) * 3600 as hour,
            AVG(value) as avg_value,
            COUNT(*) as readings
        FROM data 
        WHERE key = ? AND ts BETWEEN ? AND ?
        GROUP BY hour
        ORDER BY hour
    """
    explain_query(db, hourly_avg_query, [sample_key, window_start, window_end + 86400])
    hourly_time = Benchmark.measure do
        100.times do
            key = rand(num_sensors)
            start_ts = base_time + rand(duration - 86400)
            db.execute(hourly_avg_query, [key, start_ts, start_ts + 86400])
        end
    end
    puts hourly_time

    db.close
end

# Test cases focusing on different indexing strategies
perform_test('no_index', <<-STRUCTURE)
    CREATE TABLE IF NOT EXISTS data (
        id INTEGER PRIMARY KEY,
        key INTEGER,
        value REAL,
        ts INTEGER
    );
STRUCTURE

perform_test('ts_index', <<-STRUCTURE)
    CREATE TABLE IF NOT EXISTS data (
        id INTEGER PRIMARY KEY,
        key INTEGER,
        value REAL,
        ts INTEGER
    );
    CREATE INDEX idx_timestamp ON data(ts);
STRUCTURE

perform_test('key_ts_index', <<-STRUCTURE)
    CREATE TABLE IF NOT EXISTS data (
        id INTEGER PRIMARY KEY,
        key INTEGER,
        value REAL,
        ts INTEGER
    );
    CREATE INDEX idx_key_ts ON data(key, ts);
STRUCTURE

perform_test('partitioned', <<-STRUCTURE)
    CREATE TABLE IF NOT EXISTS data (
        id INTEGER PRIMARY KEY,
        key INTEGER,
        value REAL,
        ts INTEGER,
        hour INTEGER GENERATED ALWAYS AS (ts / 3600) STORED
    );
    CREATE INDEX idx_key_hour ON data(key, hour);
STRUCTURE
