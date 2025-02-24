class Tasks < Model
  class << self
    def setup_tables
      create_table('tasks', 
      [
        'uuid',
        'host_uuid',
        'tasktemplate_uuid',
        'opts'
      ])
    end

    def add(hsh)
      tasks = {}

      tasks['uuid'] = hsh['uuid'] || SecureRandom.uuid

      raise ArgumentError, "Host UUID is required" unless hsh['host_uuid']
      tasks['host_uuid'] = hsh['host_uuid']

      raise ArgumentError, "TaskTemplate UUID is required" unless hsh['tasktemplate_uuid']
      tasks['tasktemplate_uuid'] = hsh['tasktemplate_uuid']

      opts = hsh['opts'] || {}

      db.execute("INSERT INTO tasks (uuid, host_uuid, tasktemplate_uuid, opts) VALUES (?, ?, ?, ?)",
                  sanitize_uuid(tasks['uuid']),
                  sanitize_uuid(tasks['host_uuid']),
                  sanitize_uuid(tasks['tasktemplate_uuid']),
                  opts.to_json)

      tasks
    end

    def edit(uuid, hsh)
      opts = hsh['opts'] || {}
      db.execute("UPDATE tasks SET opts = ? WHERE uuid = '#{sanitize_uuid(uuid)}'", opts.to_json)
    end

    def size
      count('tasks')
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM tasks WHERE uuid = '#{sanitize_uuid(uuid)}'")
      transform_row(ret.first)
    end

    def delete(uuid)
      db.execute("DELETE FROM tasks WHERE uuid = '#{sanitize_uuid(uuid)}'")
      {'uuid' => uuid}
    end

    def all
      db.execute("SELECT * FROM tasks")
    end
  end
end

Activities.register("task_add") do |hsh|
  Tasks.add(
    'uuid' => hsh['uuid'],
    'host_uuid' => hsh['host_uuid'],
    'tasktemplate_uuid' => hsh['tasktemplate_uuid'],
    'opts' => hsh['opts']
  )
end

Activities.register("task_delete") do |hsh|
  Tasks.delete(hsh['uuid'])
end