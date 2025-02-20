require_relative '../db'

# Time Series Data
#
# This Model is special as it doesn't depend on Model
# but manages its own database. We do this because
# we want to keep the configuration seperated from the
# data.
class TSData
  class << self
    def setup_db
      db.execute(<<-SQL)
        CREATE TABLE IF NOT EXISTS keys (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          job_uuid TEXT NOT NULL,
          key TEXT NOT NULL
        )
      SQL

      db.execute(<<-SQL)
        CREATE TABLE IF NOT EXISTS datapoints (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key_id INTEGER NOT NULL,
          datapoint TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      SQL
    end

    def delete_db
      db.execute("DROP TABLE IF EXISTS keys")
      db.execute("DROP TABLE IF EXISTS datapoints")
      @@db.delete
      @@db = nil
    end

    def db
      @@db ||= begin
        db_file = ENV["NOF_#{$system_name}_TS_DB_FILE"] || File.join(Dir.home, '.nof', "#{$system_name}.ts.db")
        db_dir = File.dirname(db_file)
        FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)
        Database.new(db_file: db_file)
      end
    end

    def add_key(job_uuid, key)
      db.execute("INSERT INTO keys (job_uuid, key) VALUES ('#{job_uuid}', '#{key}')")
      db.execute("SELECT id FROM keys WHERE job_uuid = '#{job_uuid}' AND key = '#{key}'").first['id']
    end

    def add(hsh)
      _id = hsh['id'] || -1
      jid = hsh['job_uuid']
      key = hsh['key']
      ts = hsh['timestamp'].to_i
      v = hsh['value']

      # check if key and job_uuid combination exists
      ret = db.execute("SELECT id FROM keys WHERE job_uuid = '#{jid}' AND key = '#{key}' LIMIT 1")
      if ret.empty?
        add_key(jid, key)
      end
      ret = db.execute("SELECT id FROM keys WHERE job_uuid = '#{jid}' AND key = '#{key}' LIMIT 1")
      key_id = db.execute("SELECT id FROM keys WHERE job_uuid = '#{jid}' AND key = '#{key}' LIMIT 1").first['id']

      if _id == -1
        # insert the datapoint and ensure to get the inserted auto-incremented ID back
        db.with_transaction do |db_trans|
          db_trans.execute("INSERT INTO datapoints (key_id, datapoint, timestamp) VALUES (?, ?, ?)", [key_id, v, ts])
          _id = db_trans.execute("SELECT last_insert_rowid()").first['last_insert_rowid()']
        end
      else
        # this is a sync operation, so we need to use a fixed ID and not auto-increment
        db.execute("INSERT INTO datapoints (id, key_id, datapoint, timestamp) VALUES (?, ?, ?, ?)", [_id, key_id, v, ts])
      end

      {
        'id' => _id,
        'job_uuid' => jid,
        'key' => key,
        'value' => v,
        'timestamp' => ts
      }
    end

    # add a bulk of datapoints with a commit
    def add_bulk(key_id, datapoints)
      db.with_transaction do |conn|
        datapoints.each do |dp|
          conn.execute("INSERT INTO datapoints (key_id, datapoint, timestamp) VALUES (?, ?, ?)", [key_id, dp['value'], dp['timestamp']])
        end
      end
    end

    def all
      db.execute("SELECT
                    datapoints.id as id,
                    datapoints.datapoint as value,
                    datapoints.timestamp as timestamp,
                    keys.job_uuid as job_uuid,
                    keys.key as key
                  FROM datapoints
                  JOIN keys ON datapoints.key_id = keys.id")
    end

    def delete(id)
      raise ArgumentError, "id is required" unless id.to_s =~ /^[0-9]+$/
      db.execute("DELETE FROM datapoints WHERE id = #{id}")
    end

    def size
      db.execute("SELECT COUNT(*) AS cnt FROM datapoints").first['cnt']
    end

    def range(job_uuid, key, start_time, end_time)
      # get key_id via job_uuid and key
      key_id = db.execute("SELECT id FROM keys WHERE job_uuid = '#{job_uuid}' AND key = '#{key}'").first['id']
      db.execute("SELECT * FROM datapoints WHERE key_id = #{key_id} AND timestamp BETWEEN #{start_time} AND #{end_time}")
    end
  end
end