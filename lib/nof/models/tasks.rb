class Tasks < Model
  class << self
    def setup_tables
      create_table('tasks', 
      [
        'uuid',
        'host_uuid',
        'tasktemplate_uuid'
      ])
    end

    def add(uuid: nil, host_uuid:, tasktemplate_uuid:)
      tasks = {}

      tasks[:uuid] = uuid || SecureRandom.uuid

      raise ArgumentError, "Host UUID is required" unless host_uuid
      tasks[:host_uuid] = host_uuid

      raise ArgumentError, "TaskTemplate UUID is required" unless tasktemplate_uuid
      tasks[:tasktemplate_uuid] = tasktemplate_uuid

      db.execute("INSERT INTO tasks (uuid, host_uuid, tasktemplate_uuid) VALUES (?, ?, ?)",
                  sanitize_uuid(tasks[:uuid]),
                  sanitize_uuid(tasks[:host_uuid]),
                  sanitize_uuid(tasks[:tasktemplate_uuid]))

      tasks
    end

    def size
      count('tasks')
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM tasks WHERE uuid = '#{sanitize_uuid(uuid)}'")
      ret = ret.map do |row|
        row = row.transform_keys(&:to_sym)
        row
      end
      ret.first
    end

    def delete(uuid)
      db.execute("DELETE FROM tasks WHERE uuid = '#{sanitize_uuid(uuid)}'")
      {uuid: uuid}
    end

    def all
      debug "Tasks.all"
      db.execute("SELECT * FROM tasks")
    end
  end
end

Activities.register("task_add") do |hsh|
  Tasks.add(
    uuid: hsh[:uuid],
    host_uuid: hsh[:host_uuid],
    tasktemplate_uuid: hsh[:tasktemplate_uuid]
  )
end

Activities.register("task_delete") do |hsh|
  Tasks.delete(hsh[:uuid])
end