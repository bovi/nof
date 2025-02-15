require 'sqlite3'
require 'benchmark'

# Delete old database file if it exists
File.delete('test.db') if File.exist?('test.db')

# Open a database
db = SQLite3::Database.new 'test.db'

# Enable foreign keys and set some performance parameters
db.execute "PRAGMA foreign_keys = ON"
db.execute "PRAGMA cache_size = -2000000" # 2GB cache
db.execute "PRAGMA journal_mode = WAL"
db.execute "PRAGMA synchronous = NORMAL"

db.execute "CREATE TABLE IF NOT EXISTS data (
    id INTEGER PRIMARY KEY,
    key INTEGER,
    value REAL,
    ts INTEGER
)"

# benchmark without transaction
time = Benchmark.measure do
    11000.times do |i|
      db.execute "INSERT INTO data (key, value, ts) VALUES (?, ?, ?)", [rand(100), rand(100), Time.now.to_i + i]
    end
  end

puts "Time: #{time.real}"

# benchmark transaction
time = Benchmark.measure do
  db.transaction do
    11000.times do |i|
      db.execute "INSERT INTO data (key, value, ts) VALUES (?, ?, ?)", [rand(100), rand(100), Time.now.to_i + i]
    end
  end
end

puts "Time: #{time.real}"

class TSData
  def self.add_bulk(db, key_id, datapoints)
    db.transaction do
      datapoints.each do |dp|
        db.execute "INSERT INTO data (key, value, ts) VALUES (?, ?, ?)", [dp['key'], dp['value'], dp['timestamp']]
      end
    end
  end
end

time = Benchmark.measure do
  TSData.add_bulk(
    db,
    rand(100),
    11000.times.map { |i|
      # add a datapoint for every minute
      {
        'value' => rand(100),
        'timestamp' => Time.now.to_i + i
      }
    }
  )
end

puts "Time: #{time.real}"
db.close