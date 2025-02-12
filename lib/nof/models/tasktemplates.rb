require 'securerandom'

# A template which can be used to in combination
# with a Host to create a Task. Such a task instance
# will be executed by the Executor.
class TaskTemplates < Model
  class << self
    def setup_tables
      create_table('tasktemplates', [
        'uuid',
        'type',
        'cmd',
        'format'
      ])
    end

    def add(uuid: nil, type: nil, cmd: nil, format: nil)
      task = {}

      task[:uuid] = uuid || SecureRandom.uuid
      raise ArgumentError, "type is required" unless type

      task[:type] = type
      if type == 'shell'
        if cmd
          task[:cmd] = cmd
        else
          err "cmd is required"
          raise ArgumentError, "cmd is required"
        end
      else
        err "unknown type: #{type}"
        raise ArgumentError, "unknown type: #{type}"
      end
      task[:format] = format || {}

      db.execute("INSERT INTO tasktemplates (uuid, type, cmd, format) VALUES (?, ?, ?, ?)",
                 task[:uuid], task[:type], task[:cmd], task[:format].to_json)

      task
    end

    def size
      count("tasktemplates")
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM tasktemplates WHERE uuid = ?", uuid)
      ret = ret.map do |row|
        row = row.transform_keys(&:to_sym)
        row[:format] = JSON.parse(row[:format]).transform_keys(&:to_sym)
        row
      end
      ret.first
    end

    def delete(uuid)
      ret = db.execute("DELETE FROM tasktemplates WHERE uuid = '#{uuid}'")
      {uuid: uuid}
    end

    def inspect
      db.execute("SELECT * FROM tasktemplates").inspect
    end

    def to_json
      db.execute("SELECT * FROM tasktemplates").map do |row|
        row = row.transform_keys(&:to_sym)
        row[:format] = JSON.parse(row[:format]).transform_keys(&:to_sym)
        row
      end.to_json
    end

    def all
      db.execute("SELECT * FROM tasktemplates")
    end
  end
end

Activities.register("tasktemplate_add") do |hsh|
  TaskTemplates.add(
    uuid: hsh[:uuid],
    type: hsh[:type],
    cmd: hsh[:cmd],
    format: hsh[:format]
  )
end

Activities.register("tasktemplate_delete") do |hsh|
  TaskTemplates.delete(hsh[:uuid])
end
