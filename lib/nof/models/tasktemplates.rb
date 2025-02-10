require 'securerandom'

# A template which can be used to in combination
# with a Host to create a Task. Such a task instance
# will be executed by the Executor.
class TaskTemplates
  class << self
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

      @task_templates ||= []
      @task_templates << task

      task
    end

    def size
      (@task_templates || []).size
    end

    def get(uuid)
      (@task_templates || []).find { |t| t[:uuid] == uuid }
    end

    def delete(uuid)
      (@task_templates || []).delete_if { |t| t[:uuid] == uuid }
      {uuid: uuid}
    end

    def inspect
      (@task_templates || []).inspect
    end

    def to_json
      (@task_templates || []).to_json
    end

    def all
      (@task_templates || [])
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
