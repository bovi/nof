class Hosts < Model
  class << self
    def setup_tables
      create_table('hosts', ['uuid', 'hostname', 'host', 'ip'])
    end

    def add(hsh)
      hosts = {}

      hosts['uuid'] = hsh['uuid'] || SecureRandom.uuid

      raise ArgumentError, "hostname is required" unless hsh['hostname']
      hosts['hostname'] = hsh['hostname']

      raise ArgumentError, "ip is required" unless hsh['ip']
      hosts['ip'] = hsh['ip']

      db.execute("INSERT INTO hosts (uuid, hostname, ip) VALUES (?, ?, ?)",
                 sanitize_uuid(hosts['uuid']),
                 hosts['hostname'],
                 hosts['ip'])

      hosts
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM hosts WHERE uuid = '#{sanitize_uuid(uuid)}'")
      ret.first
    end

    def delete(uuid)
      # first delete all tasks for this host
      Tasks.all.select { |t| t['host_uuid'] == uuid }.each do |t|
        Tasks.delete(t['uuid'])
      end
      db.execute("DELETE FROM hosts WHERE uuid = '#{sanitize_uuid(uuid)}'")
      {'uuid' => uuid}
    end

    def size
      count('hosts')
    end

    def all
      db.execute("SELECT * FROM hosts")
    end

    def each(&block)
      db.execute("SELECT * FROM hosts").each do |row|
        block.call(row)
      end
    end
  end
end

Activities.register("host_add") do |hsh|
  Hosts.add(
    'uuid' => hsh['uuid'],
    'hostname' => hsh['hostname'],
    'ip' => hsh['ip']
  )
end

Activities.register("host_delete") do |hsh|
  Hosts.delete(hsh['uuid'])
end
