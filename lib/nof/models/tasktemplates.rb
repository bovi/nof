require 'securerandom'

# A template which can be used to in combination
# with a Host to create a Task. Such a task instance
# will be executed by the Executor.
class TaskTemplates < Model
  class << self
    # the opts field is a json field
    def setup_tables
      create_table('tasktemplates', [
        'uuid',
        'type',
        'opts'
      ])
    end

    def add(hsh)
      task = {'uuid' => nil, 'type' => nil, 'opts' => {}}

      task['uuid'] = hsh['uuid'] || SecureRandom.uuid
      raise ArgumentError, "type is required" unless hsh['type']

      task['type'] = hsh['type']
      if hsh['type'] == 'shell'
        %w[cmd template pattern interval].each do |key|
          if hsh['opts'][key]
            task['opts'][key] = hsh['opts'][key]
          else
            err "'#{key}' argument is required for shell tasks"
            raise ArgumentError, "'#{key}' argument is required for shell tasks"
          end
        end
      elsif hsh['type'] == 'oneshot'
        %w[cmd template pattern].each do |key|
          if hsh['opts'][key]
            task['opts'][key] = hsh['opts'][key]
          else
            err "'#{key}' argument is required for oneshot tasks"
            raise ArgumentError, "'#{key}' argument is required for oneshot tasks"
          end
        end
      else
        err "unknown type: #{hsh['type']}"
        raise ArgumentError, "unknown type: #{hsh['type']}"
      end

      db.execute("INSERT INTO tasktemplates (uuid, type, opts) VALUES (?, ?, ?)",
                 sanitize_uuid(task['uuid']),
                 task['type'],
                 task['opts'].to_json)

      task
    end

    def size
      count("tasktemplates")
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM tasktemplates WHERE uuid = '#{sanitize_uuid(uuid)}'")
      transform_row(ret.first)
    end

    def delete(uuid)
      # first delete all tasks for this task template
      Tasks.all.select { |t| t['tasktemplate_uuid'] == uuid }.each do |t|
        Tasks.delete(t['uuid'])
      end
      db.execute("DELETE FROM tasktemplates WHERE uuid = '#{sanitize_uuid(uuid)}'")
      {'uuid' => uuid}
    end

    def inspect
      db.execute("SELECT * FROM tasktemplates").inspect
    end

    def to_json
      db.execute("SELECT * FROM tasktemplates").map do |row|
        transform_row(row)
      end.to_json
    end

    def all
      db.execute("SELECT * FROM tasktemplates").map do |row|
        transform_row(row)
      end
    end

    def each(&block)
      db.execute("SELECT * FROM tasktemplates").each do |row|
        block.call(transform_row(row))
      end
    end
  end
end

Activities.register("tasktemplate_add") do |hsh|
  TaskTemplates.add(
    'uuid' => hsh['uuid'],
    'type' => hsh['type'],
    'opts' => hsh['opts']
  )
end

Activities.register("tasktemplate_delete") do |hsh|
  TaskTemplates.delete(hsh['uuid'])
end
