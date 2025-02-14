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
        'opts'
      ])
    end

    def add(uuid: nil, type: nil, opts: {})
      task = {uuid: nil, type: nil, opts: {}}

      task[:uuid] = uuid || SecureRandom.uuid
      raise ArgumentError, "type is required" unless type

      task[:type] = type
      if type == 'shell'
        if opts[:cmd]
          task[:opts][:cmd] = opts[:cmd]
        else
          err "cmd is required"
          raise ArgumentError, "cmd is required"
        end
      else
        err "unknown type: #{type}"
        raise ArgumentError, "unknown type: #{type}"
      end
      task[:opts][:format] = opts[:format] || {}

      db.execute("INSERT INTO tasktemplates (uuid, type, opts) VALUES (?, ?, ?)",
                 task[:uuid], task[:type], task[:opts].to_json)

      task
    end

    def size
      count("tasktemplates")
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM tasktemplates WHERE uuid = '#{uuid}'")
      ret = ret.map do |row|
        row = row.transform_keys(&:to_sym)
        row[:opts] = JSON.parse(row[:opts]).transform_keys(&:to_sym)
        row[:opts][:format] = row[:opts][:format].transform_keys(&:to_sym)
        row
      end
      ret.first
    end

    def delete(uuid)
      # first delete all tasks for this task template
      Tasks.all.select { |t| t['tasktemplate_uuid'] == uuid }.each do |t|
        Tasks.delete(t['uuid'])
      end
      db.execute("DELETE FROM tasktemplates WHERE uuid = '#{uuid}'")
      {uuid: uuid}
    end

    def inspect
      db.execute("SELECT * FROM tasktemplates").inspect
    end

    def to_json
      db.execute("SELECT * FROM tasktemplates").map do |row|
        row = row.transform_keys(&:to_sym)
        row[:opts] = JSON.parse(row[:opts]).transform_keys(&:to_sym)
        row[:opts][:format] = row[:opts][:format].transform_keys(&:to_sym)
        row
      end.to_json
    end

    def all
      ret = db.execute("SELECT * FROM tasktemplates").map do |row|
        row = row.transform_keys(&:to_sym)
        row[:opts] = JSON.parse(row[:opts]).transform_keys(&:to_sym)
        row[:opts][:format] = row[:opts][:format].transform_keys(&:to_sym)
        row
      end
      debug "ret: #{ret.inspect}"
      ret
    end

    def each(&block)
      db.execute("SELECT * FROM tasktemplates").each do |row|
        row = row.transform_keys(&:to_sym)
        row[:opts] = JSON.parse(row[:opts]).transform_keys(&:to_sym)
        row[:opts][:format] = row[:opts][:format].transform_keys(&:to_sym)
        block.call(row)
      end
    end
  end
end

Activities.register("tasktemplate_add") do |hsh|
  TaskTemplates.add(
    uuid: hsh[:uuid],
    type: hsh[:type],
    opts: hsh[:opts]
  )
end

Activities.register("tasktemplate_delete") do |hsh|
  TaskTemplates.delete(hsh[:uuid])
end
