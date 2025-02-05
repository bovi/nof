module NOF
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
        hosts << {
          'uuid' => row[0],
          'name' => row[1],
          'ip' => row[2],
          'group_uuids' => row[3] ? row[3].split(',') : []
        }
      end
      hosts
    end

    def self.add(name, ip, with_uuid: nil)
      uuid = with_uuid || SecureRandom.uuid
      debug("Adding host: #{uuid} #{name} #{ip}")
      db.execute(
        "INSERT INTO hosts (uuid, name, ip) VALUES (?, ?, ?)",
        [uuid, name, ip]
      )
      uuid
    end

    def self.remove(uuid)
      db.transaction do
        db.execute("DELETE FROM host_groups WHERE host_uuid = ?", [uuid])
        db.execute("DELETE FROM task_results WHERE host_uuid = ?", [uuid])
        db.execute("DELETE FROM hosts WHERE uuid = ?", [uuid])
      end
    end

    def self.clean!
      db.execute("DELETE FROM hosts")
    end

    def self.get(uuid)
      db.execute("SELECT * FROM hosts WHERE uuid = ?", [uuid]).first
    end
  end
end 