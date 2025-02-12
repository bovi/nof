class Hosts < Model
  class << self
    def setup_tables
      create_table('hosts', ['uuid', 'hostname', 'host', 'ip'])
    end

    def add(uuid: nil, hostname:, ip:)
      hosts = {}

      hosts[:uuid] = uuid || SecureRandom.uuid

      raise ArgumentError, "hostname is required" unless hostname
      hosts[:hostname] = hostname

      raise ArgumentError, "ip is required" unless ip
      hosts[:ip] = ip

      db.execute("INSERT INTO hosts (uuid, hostname, ip) VALUES (?, ?, ?)", hosts[:uuid], hosts[:hostname], hosts[:ip])

      hosts
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM hosts WHERE uuid = ?", uuid)
      ret = ret.map do |row|
        row = row.transform_keys(&:to_sym)
        row
      end
      ret.first
    end

    def delete(uuid)
      db.execute("DELETE FROM hosts WHERE uuid = '#{uuid}'")
      {uuid: uuid}
    end

    def size
      count('hosts')
    end

    def all
      db.execute("SELECT * FROM hosts")
    end
  end
end

Activities.register("host_add") do |hsh|
  Hosts.add(
    uuid: hsh[:uuid],
    hostname: hsh[:hostname],
    ip: hsh[:ip]
  )
end

Activities.register("host_delete") do |hsh|
  Hosts.delete(hsh[:uuid])
end
