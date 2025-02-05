module NOF
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
      db.execute("DELETE FROM host_groups WHERE group_uuid = ?", [uuid])
      db.execute("DELETE FROM task_template_groups WHERE group_uuid = ?", [uuid])
      db.execute("DELETE FROM groups WHERE uuid = ?", [uuid])
    end

    def self.clean!
      db.execute("DELETE FROM groups")
    end

    def self.add_host(group_uuid, host_uuid)
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

    def self.add_task_template(group_uuids, template_uuid)
      group_uuids.each do |group_uuid|
        db.execute(
          "INSERT INTO task_template_groups (group_uuid, task_template_uuid) VALUES (?, ?)",
          [group_uuid, template_uuid]
        )
      end
    end

    def self.remove_task_template(group_uuids, template_uuid)
      group_uuids.each do |group_uuid|
        db.execute(
          "DELETE FROM task_template_groups WHERE group_uuid = ? AND task_template_uuid = ?",
          [group_uuid, template_uuid]
        )
      end
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
end 