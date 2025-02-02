require 'securerandom'
require 'json'
require 'sqlite3'

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
    db.execute("DELETE FROM tasks WHERE uuid = ?", [uuid])
  end

  def self.add_result(uuid, result, timestamp)
    db.execute(
      "INSERT INTO task_results (task_uuid, result, timestamp) VALUES (?, ?, ?)",
      [uuid, result, timestamp]
    )
  end

  def self.clean!
    db.execute("DELETE FROM tasks")
  end
end

class TaskTemplates
  extend DatabaseConfig

  def self.setup_tables(db)
    # Drop old task_results table if it exists
    db.execute("DROP TABLE IF EXISTS task_results")

    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS task_templates (
        uuid TEXT PRIMARY KEY,
        command TEXT NOT NULL,
        schedule INTEGER NOT NULL,
        type TEXT NOT NULL,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    SQL

    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS task_template_groups (
        task_template_uuid TEXT NOT NULL,
        group_uuid TEXT NOT NULL,
        PRIMARY KEY (task_template_uuid, group_uuid),
        FOREIGN KEY (task_template_uuid) REFERENCES task_templates(uuid),
        FOREIGN KEY (group_uuid) REFERENCES groups(uuid)
      )
    SQL

    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS task_results (
        id INTEGER PRIMARY KEY,
        task_template_uuid TEXT NOT NULL,
        host_uuid TEXT NOT NULL,
        result TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (task_template_uuid) REFERENCES task_templates(uuid),
        FOREIGN KEY (host_uuid) REFERENCES hosts(uuid)
      )
    SQL
  end

  def self.all
    templates = []
    db.execute(<<-SQL) do |row|
      SELECT t.uuid, t.command, t.schedule, t.type, 
             GROUP_CONCAT(tg.group_uuid) as group_uuids
      FROM task_templates t
      LEFT JOIN task_template_groups tg ON t.uuid = tg.task_template_uuid
      GROUP BY t.uuid, t.command, t.schedule, t.type
    SQL
      templates << {
        'uuid' => row[0],
        'command' => row[1],
        'schedule' => row[2],
        'type' => row[3],
        'group_uuids' => row[4] ? row[4].split(',') : []
      }
    end
    templates
  end

  def self.add(command, schedule, type, group_uuids = [], with_uuid: nil)
    uuid = with_uuid || SecureRandom.uuid
    db.transaction do
      db.execute(
        "INSERT INTO task_templates (uuid, command, schedule, type) VALUES (?, ?, ?, ?)",
        [uuid, command, schedule.to_i, type]
      )
      
      # Add group associations
      group_uuids.each do |group_uuid|
        db.execute(
          "INSERT INTO task_template_groups (task_template_uuid, group_uuid) VALUES (?, ?)",
          [uuid, group_uuid]
        )
      end
    end
    uuid
  end

  def self.remove(uuid)
    db.transaction do
      db.execute("DELETE FROM task_results WHERE task_template_uuid = ?", [uuid])
      db.execute("DELETE FROM task_template_groups WHERE task_template_uuid = ?", [uuid])
      db.execute("DELETE FROM task_templates WHERE uuid = ?", [uuid])
    end
  end

  def self.add_result(template_uuid, host_uuid, result, timestamp)
    db.execute(
      "INSERT INTO task_results (task_template_uuid, host_uuid, result, timestamp) VALUES (?, ?, ?, ?)",
      [template_uuid, host_uuid, result, timestamp]
    )
  end

  def self.get_tasks_for_host(host_uuid)
    log("Getting tasks for host: #{host_uuid}")
    
    # First, let's verify the exact host_uuid we're querying with
    log("Exact host_uuid being queried: '#{host_uuid}'")
    
    # Let's run each part of the query separately to see where it might be failing
    host_check = db.execute("SELECT * FROM host_groups WHERE host_uuid = ?", [host_uuid])
    log("Host groups check: #{host_check.inspect}")
    
    template_check = db.execute(
      "SELECT t.*, tg.group_uuid 
       FROM task_templates t
       JOIN task_template_groups tg ON t.uuid = tg.task_template_uuid
       WHERE tg.group_uuid IN (
         SELECT group_uuid FROM host_groups WHERE host_uuid = ?
       )",
      [host_uuid]
    )
    log("Template check: #{template_check.inspect}")

    # Now the full query with detailed logging
    tasks = db.execute(<<-SQL, [host_uuid]).map do |row|
      SELECT DISTINCT t.uuid, t.command, t.schedule, t.type
      FROM task_templates t
      JOIN task_template_groups tg ON t.uuid = tg.task_template_uuid
      JOIN host_groups hg ON tg.group_uuid = hg.group_uuid
      WHERE hg.host_uuid = ?
    SQL
      {
        'uuid' => row[0],
        'command' => row[1],
        'schedule' => row[2],
        'type' => row[3]
      }
    end
    log("Final tasks result: #{tasks.inspect}")
    tasks
  end

  def self.clean!
    db.transaction do
      db.execute("DELETE FROM task_results")
      db.execute("DELETE FROM task_template_groups")
      db.execute("DELETE FROM task_templates")
    end
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

    # Join table for Hosts and Groups
    db.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS host_groups (
        host_uuid TEXT NOT NULL,
        group_uuid TEXT NOT NULL,
        PRIMARY KEY (host_uuid, group_uuid),
        FOREIGN KEY (host_uuid) REFERENCES hosts(uuid),
        FOREIGN KEY (group_uuid) REFERENCES groups(uuid)
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

  def self.add_host(group_uuid, host_uuid)
    log("Adding host #{host_uuid} to group #{group_uuid}")
    db.execute(
      "INSERT INTO host_groups (group_uuid, host_uuid) VALUES (?, ?)",
      [group_uuid, host_uuid]
    )
  end

  def self.remove_host(group_uuid, host_uuid)
    db.execute(
      "DELETE FROM host_groups WHERE group_uuid = ? AND host_uuid = ?",
      [group_uuid, host_uuid]
    )
  end

  def self.add_task_template(group_uuid, template_uuid)
    db.execute(
      "INSERT INTO task_template_groups (group_uuid, task_template_uuid) VALUES (?, ?)",
      [group_uuid, template_uuid]
    )
  end

  def self.remove_task_template(group_uuid, template_uuid)
    db.execute(
      "DELETE FROM task_template_groups WHERE group_uuid = ? AND task_template_uuid = ?",
      [group_uuid, template_uuid]
    )
  end

  def self.get_groups_for_template(template_uuid)
    db.execute(
      "SELECT g.uuid, g.name FROM groups g 
       JOIN task_template_groups tg ON g.uuid = tg.group_uuid 
       WHERE tg.task_template_uuid = ?", 
      [template_uuid]
    ).map { |row| { 'uuid' => row[0], 'name' => row[1] } }
  end

  def self.get_groups_for_host(host_uuid)
    db.execute(
      "SELECT g.uuid, g.name FROM groups g 
       JOIN host_groups hg ON g.uuid = hg.group_uuid 
       WHERE hg.host_uuid = ?", 
      [host_uuid]
    ).map { |row| { 'uuid' => row[0], 'name' => row[1] } }
  end

  def self.get_host_count(group_uuid)
    db.get_first_value(
      "SELECT COUNT(*) FROM host_groups WHERE group_uuid = ?", 
      [group_uuid]
    )
  end

  def self.get_template_count(group_uuid)
    db.get_first_value(
      "SELECT COUNT(*) FROM task_template_groups WHERE group_uuid = ?", 
      [group_uuid]
    )
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
    db.execute(<<-SQL) do |row|
      SELECT h.uuid, h.name, h.ip, GROUP_CONCAT(hg.group_uuid) as group_uuids
      FROM hosts h
      LEFT JOIN host_groups hg ON h.uuid = hg.host_uuid
      GROUP BY h.uuid, h.name, h.ip
    SQL
      log("Raw row from database: #{row.inspect}")
      hosts << {
        'uuid' => row[0],
        'name' => row[1],
        'ip' => row[2],
        'group_uuids' => row[3] ? row[3].split(',') : []
      }
    end
    log("Hosts: #{hosts.inspect}")
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
    db.transaction do
      # First remove any host_groups associations
      db.execute("DELETE FROM host_groups WHERE host_uuid = ?", [uuid])
      # Then remove any task_results associated with this host
      db.execute("DELETE FROM task_results WHERE host_uuid = ?", [uuid])
      # Finally remove the host itself
      db.execute("DELETE FROM hosts WHERE uuid = ?", [uuid])
    end
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

  def self.add_task_template(uuid, command, schedule, type, group_uuids)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { 
      uuid: uuid, 
      command: command, 
      schedule: schedule, 
      type: type,
      group_uuids: group_uuids 
    }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'add_task_template', options.to_json]
    )
  end

  def self.delete_task_template(uuid)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { uuid: uuid }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'delete_task_template', options.to_json]
    )
  end

  def self.add_host_to_group(host_uuid, group_uuid)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { host_uuid: host_uuid, group_uuid: group_uuid }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'add_host_to_group', options.to_json]
    )
  end

  def self.add_template_to_group(template_uuid, group_uuid)
    activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    options = { template_uuid: template_uuid, group_uuid: group_uuid }
    db.execute(
      "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
      [activity_id, Time.now.to_i, 'add_template_to_group', options.to_json]
    )
  end

  def self.clean!
    db.execute("DELETE FROM activities")
  end
end

def log(message)
  return if ENV['NOF_LOGGING']&.to_i == 0
  puts "[#{Time.now}] #{message}"
end

module ResponseHelper
  def json_response(response, data)
    response.status = 200
    response['Content-Type'] = 'application/json'
    response.body = data.to_json
  end
end