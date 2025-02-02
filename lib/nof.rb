require 'securerandom'
require 'json'
require 'sqlite3'

module DatabaseConfig
  def db_path
    @db_path ||= File.join(CONFIG_DIR, 'nof.db')
  end

  def db
    Thread.current[:nof_db] ||= begin
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

  # Optional: method to close all database connections across all threads
  def self.close_all_connections
    Thread.list.each do |thread|
      if thread[:nof_db]
        thread[:nof_db].close rescue nil
        thread[:nof_db] = nil
      end
    end
  end
end

class Dashboard
  extend DatabaseConfig
  VERSION = '0.1'
  DEFAULT_PORT = 1080

  def self.setup_tables(db)
    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS dashboard_state (
        id INTEGER PRIMARY KEY,
        state TEXT NOT NULL
      )
    SQL
  end

  def self.state
    result = db.get_first_value("SELECT state FROM dashboard_state ORDER BY id DESC LIMIT 1")
    result ? result.to_sym : :unknown
  end

  def self.state=(_state)
    db.execute("INSERT INTO dashboard_state (state) VALUES (?)", [_state.to_s])
  end
end

class Controller
  extend DatabaseConfig
  VERSION = '0.1'
  DEFAULT_PORT = 1880
end

class Executor
  VERSION = '0.1'
end

class Tasks
  extend DatabaseConfig

  def self.setup_tables(db)
    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS tasks (
        uuid TEXT PRIMARY KEY,
        command TEXT NOT NULL,
        schedule INTEGER NOT NULL,
        type TEXT NOT NULL,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    SQL

    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS task_results (
        id INTEGER PRIMARY KEY,
        task_uuid TEXT NOT NULL,
        result TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (task_uuid) REFERENCES tasks(uuid)
      )
    SQL
  end

  def self.all
    tasks = []
    db.execute("SELECT uuid, command, schedule, type FROM tasks") do |row|
      tasks << {
        'uuid' => row[0],
        'command' => row[1],
        'schedule' => row[2],
        'type' => row[3]
      }
    end
    tasks
  end

  def self.add(command, schedule, type, with_uuid: nil)
    uuid = with_uuid || SecureRandom.uuid
    db.execute(
      "INSERT INTO tasks (uuid, command, schedule, type) VALUES (?, ?, ?, ?)",
      [uuid, command, schedule.to_i, type]
    )
    uuid
  end

  def self.remove(uuid)
    db.execute("DELETE FROM task_results WHERE task_uuid = ?", [uuid])
    db.execute("DELETE FROM tasks WHERE uuid = ?", [uuid])
  end

  def self.add_result(uuid, result, timestamp)
    db.execute(
      "INSERT INTO task_results (task_uuid, result, timestamp) VALUES (?, ?, ?)",
      [uuid, result, timestamp]
    )
  end

  def self.clean!
    # Delete in correct order due to foreign key constraint
    db.execute("DELETE FROM task_results")
    db.execute("DELETE FROM tasks")
  end
end

class Groups
  extend DatabaseConfig

  def self.setup_tables(db)
    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS groups (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    SQL
  end

  def self.all
    groups = []
    db.execute("SELECT uuid, name FROM groups") do |row|
      groups << {
        'uuid' => row[0],
        'name' => row[1]
      }
    end
    groups
  end

  def self.add(name, with_uuid: nil)
    uuid = with_uuid || SecureRandom.uuid
    db.execute(
      "INSERT INTO groups (uuid, name) VALUES (?, ?)",
      [uuid, name]
    )
    uuid
  end

  def self.remove(uuid)
    db.execute("DELETE FROM groups WHERE uuid = ?", [uuid])
  end

  def self.clean!
    db.execute("DELETE FROM groups")
  end
end

class Hosts
  extend DatabaseConfig

  def self.setup_tables(db)
    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS hosts (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ip TEXT NOT NULL,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    SQL
  end

  def self.all
    hosts = []
    db.execute("SELECT uuid, name, ip FROM hosts") do |row|
      hosts << {
        'uuid' => row[0],
        'name' => row[1],
        'ip' => row[2]
      }
    end
    hosts
  end

  def self.add(name, ip, with_uuid: nil)
    uuid = with_uuid || SecureRandom.uuid
    db.execute(
      "INSERT INTO hosts (uuid, name, ip) VALUES (?, ?, ?)",
      [uuid, name, ip]
    )
    uuid
  end

  def self.remove(uuid)
    db.execute("DELETE FROM hosts WHERE uuid = ?", [uuid])
  end

  def self.clean!
    db.execute("DELETE FROM hosts")
  end
end

class Activities
  extend DatabaseConfig

  def self.setup_tables(db)
    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS activities (
        id INTEGER PRIMARY KEY,
        activity_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        options TEXT NOT NULL,  -- JSON string
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    SQL
  end

  def self.all
    activities = []
    db.execute("SELECT activity_id, timestamp, type, options FROM activities ORDER BY timestamp DESC") do |row|
      activities << {
        'activity_id' => row[0],
        'timestamp' => row[1],
        'type' => row[2],
        'opt' => JSON.parse(row[3])
      }
    end
    activities
  end

  def self.any?
    db.get_first_value("SELECT EXISTS(SELECT 1 FROM activities)") == 1
  end

  def self.add_task(uuid, command, schedule, type)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { uuid: uuid, command: command, schedule: schedule, type: type }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'add_task', options.to_json]
    )
  end

  def self.delete_task(uuid)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { uuid: uuid }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'delete_task', options.to_json]
    )
  end

  def self.add_host(uuid, name, ip)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { uuid: uuid, name: name, ip: ip }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'add_host', options.to_json]
    )
  end

  def self.delete_host(uuid)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { uuid: uuid }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'delete_host', options.to_json]
    )
  end

  def self.add_group(uuid, name)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { uuid: uuid, name: name }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'add_group', options.to_json]
    )
  end

  def self.delete_group(uuid)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { uuid: uuid }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'delete_group', options.to_json]
    )
  end

  def self.clean!
    db.execute("DELETE FROM activities")
  end
end

def log(message)
  return if ENV['DISABLE_LOGGING']
  puts "[#{Time.now}] #{message}"
end

module ResponseHelper
  def json_response(response, data)
    response.status = 200
    response['Content-Type'] = 'application/json'
    response.body = data.to_json
  end
end