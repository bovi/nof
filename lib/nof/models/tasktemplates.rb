require 'securerandom'

# A template which can be used to in combination
# with a Host to create a Task. Such a task instance
# will be executed by the Executor.
class TaskTemplates
  class << self
    def add(uuid: nil, cmd: nil, format: nil)
      task = {}
      task[:uuid] = uuid || SecureRandom.uuid
      raise ArgumentError, "cmd is required" unless cmd
      task[:cmd] = cmd
      task[:format] = format

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
    end

    def inspect
      (@task_templates || []).inspect
    end

    def to_json
      (@task_templates || []).to_json
    end
  end
end

Activities.register("tasktemplate_add") do |hsh|
  TaskTemplates.add(uuid: hsh[:uuid], cmd: hsh[:cmd], format: hsh[:format])
end

Activities.register("tasktemplate_delete") do |hsh|
  TaskTemplates.delete(hsh[:uuid])
end
