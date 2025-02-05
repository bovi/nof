module NOF
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
end 