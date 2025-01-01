require 'securerandom'
require 'json'

class Tasks
  def self.all
    # iterate over all files in the tasks directory
    # and return the contents as an array of tasks
    tasks = []
    Dir.glob(File.join(CONFIG_DIR, 'tasks', '*')).each do |task_file|
      task = JSON.parse(File.read(task_file))
      task['uuid'] = File.basename(task_file)
      tasks << task
    end
    tasks
  end

  def self.add(command, schedule, type, with_uuid: nil)
    # create a new task file in the tasks directory
    # with the given command, schedule, and type
    uuid = with_uuid || SecureRandom.uuid
    task = { command: command, schedule: schedule, type: type }
    File.write(File.join(CONFIG_DIR, 'tasks', uuid), task.to_json)
  end

  def self.remove(uuid)
    # remove the task file with the given uuid
    File.delete(File.join(CONFIG_DIR, 'tasks', uuid))
  end

  def self.add_result(uuid, result, timestamp)
    task_result_dir = File.join(CONFIG_DIR, 'results', uuid)
    Dir.mkdir(task_result_dir) unless Dir.exist?(task_result_dir)
    task_result_file = File.join(task_result_dir, timestamp.to_s)
    File.write(task_result_file, result)
  end

  def self.clean!
    # remove tasks in tasks directory
    Dir.glob(File.join(CONFIG_DIR, 'tasks', '*')).each do |task_file|
      File.delete(task_file)
    end
  end
end