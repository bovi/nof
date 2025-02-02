require 'securerandom'
require 'json'

class Dashboard
  VERSION = '0.1'
  DEFAULT_PORT = 1080

  def self.state
    File.read(File.join(CONFIG_DIR, 'state')).strip.to_sym
  end

  def self.state=(_state)
    File.write(File.join(CONFIG_DIR, 'state'), _state)
  end
end

class Controller
  VERSION = '0.1'
  DEFAULT_PORT = 1880
end 

class Executor
  VERSION = '0.1'
end

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
    task = { command: command, schedule: schedule.to_i, type: type }
    File.write(File.join(CONFIG_DIR, 'tasks', uuid), task.to_json)
    uuid
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

class Groups
  def self.all
    groups = []
    Dir.glob(File.join(CONFIG_DIR, 'groups', '*')).each do |group_file|
      group = JSON.parse(File.read(group_file))
      group['uuid'] = File.basename(group_file)
      groups << group
    end
    groups
  end

  def self.add(name, with_uuid: nil)
    uuid = with_uuid || SecureRandom.uuid
    group = { name: name }
    File.write(File.join(CONFIG_DIR, 'groups', uuid), group.to_json)
    uuid
  end

  def self.remove(uuid)
    File.delete(File.join(CONFIG_DIR, 'groups', uuid))
  end

  def self.clean!
    Dir.glob(File.join(CONFIG_DIR, 'groups', '*')).each do |group_file|
      File.delete(group_file)
    end
  end
end

class Hosts
  def self.all
    hosts = []
    Dir.glob(File.join(CONFIG_DIR, 'hosts', '*')).each do |host_file|
      host = JSON.parse(File.read(host_file))
      host['uuid'] = File.basename(host_file)
      hosts << host
    end
    hosts
  end

  def self.add(name, ip, with_uuid: nil)
    uuid = with_uuid || SecureRandom.uuid
    host = { name: name, ip: ip }
    File.write(File.join(CONFIG_DIR, 'hosts', uuid), host.to_json)
    uuid
  end

  def self.remove(uuid)
    File.delete(File.join(CONFIG_DIR, 'hosts', uuid))
  end

  def self.clean!
    Dir.glob(File.join(CONFIG_DIR, 'hosts', '*')).each do |host_file|
      File.delete(host_file)
    end
  end
end

class Activities
  def self.all
    activities = []
    Dir.glob(File.join(CONFIG_DIR, 'activities', '*')).each do |activity_file|
      activity = JSON.parse(File.read(activity_file))
      activity['activity_id'] = File.basename(activity_file)
      activities << activity
    end
    activities
  end

  def self.any?
    all.any?
  end

  def self.add_task(uuid, command, schedule, type)
    activity = { timestamp: Time.now.to_i, type: 'add_task', opt: { uuid: uuid, command: command, schedule: schedule, type: type } }
    n = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    File.write(File.join(CONFIG_DIR, 'activities', n), activity.to_json)
  end

  def self.delete_task(uuid)
    activity = { timestamp: Time.now.to_i, type: 'delete_task', opt: { uuid: uuid } }
    n = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    File.write(File.join(CONFIG_DIR, 'activities', n), activity.to_json)
  end

  def self.add_host(uuid, name, ip)
    activity = { timestamp: Time.now.to_i, type: 'add_host', opt: { uuid: uuid, name: name, ip: ip } }
    n = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    File.write(File.join(CONFIG_DIR, 'activities', n), activity.to_json)
  end

  def self.delete_host(uuid)
    activity = { timestamp: Time.now.to_i, type: 'delete_host', opt: { uuid: uuid } }
    n = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    File.write(File.join(CONFIG_DIR, 'activities', n), activity.to_json)
  end

  def self.add_group(uuid, name)
    activity = { timestamp: Time.now.to_i, type: 'add_group', opt: { uuid: uuid, name: name } }
    n = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    File.write(File.join(CONFIG_DIR, 'activities', n), activity.to_json)
  end

  def self.delete_group(uuid)
    activity = { timestamp: Time.now.to_i, type: 'delete_group', opt: { uuid: uuid } }
    n = "#{Time.now.to_i}-#{SecureRandom.uuid}"
    File.write(File.join(CONFIG_DIR, 'activities', n), activity.to_json)
  end

  def self.clean!
    Dir.glob(File.join(CONFIG_DIR, 'activities', '*')).each do |activity_file|
      File.delete(activity_file)
    end
  end
end

def log(message)
  return if ENV['DISABLE_LOGGING']
  puts "[#{Time.now}] #{message}"
end

module ResponseHelper
  def json_response(response, data)
    response.status = 200
    response['Content-Type'] = 'application/json'
    response.body = data.to_json
  end
end