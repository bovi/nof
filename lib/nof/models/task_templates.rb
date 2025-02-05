module NOF
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
          formatter_pattern TEXT,
          formatter_template TEXT,
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
               t.formatter_pattern, t.formatter_template,
               GROUP_CONCAT(tg.group_uuid) as group_uuids
        FROM task_templates t
        LEFT JOIN task_template_groups tg ON t.uuid = tg.task_template_uuid
        GROUP BY t.uuid, t.command, t.schedule, t.type, t.formatter_pattern, t.formatter_template
      SQL
        templates << {
          'uuid' => row[0],
          'command' => row[1],
          'schedule' => row[2],
          'type' => row[3],
          'formatter_pattern' => row[4],
          'formatter_template' => row[5],
          'group_uuids' => row[6] ? row[6].split(',') : []
        }
      end
      templates
    end

    def self.add(command, schedule, type, group_uuids = [], formatter: nil, with_uuid: nil)
      debug("TaskTemplates::add Adding task template with data: #{command}, #{schedule}, #{type}, #{group_uuids}, #{formatter}, #{with_uuid}")
      uuid = with_uuid || SecureRandom.uuid
      db.transaction do
        db.execute(
          "INSERT INTO task_templates (uuid, command, schedule, type, formatter_pattern, formatter_template) VALUES (?, ?, ?, ?, ?, ?)",
          [uuid, command, schedule.to_i, type, formatter['pattern'], formatter['template']]
        )
        
        # Add group associations
        group_uuids.each do |group_uuid|
          debug("Adding task template #{uuid} to group #{group_uuid}")
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
      tasks = db.execute(<<-SQL, [host_uuid]).map do |row|
        SELECT DISTINCT t.uuid, t.command, t.schedule, t.type, t.formatter_pattern, t.formatter_template
        FROM task_templates t
        JOIN task_template_groups tg ON t.uuid = tg.task_template_uuid
        JOIN host_groups hg ON tg.group_uuid = hg.group_uuid
        WHERE hg.host_uuid = ?
      SQL
        {
          'uuid' => row[0],
          'command' => row[1],
          'schedule' => row[2],
          'type' => row[3],
          'formatter_pattern' => row[4],
          'formatter_template' => row[5]
        }
      end
      tasks
    end

    def self.clean!
      db.transaction do
        db.execute("DELETE FROM task_results")
        db.execute("DELETE FROM task_template_groups")
        db.execute("DELETE FROM task_templates")
      end
    end

    def self.get(uuid)
      db.execute("SELECT * FROM task_templates WHERE uuid = ?", [uuid]).first
    end
  end
end 