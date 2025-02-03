require 'json'
require 'net/http'
require 'thread'

require_relative 'lib/nof'

CONTROLLER_HOST = ENV['CONTROLLER_HOST'] || 'localhost'
CONTROLLER_PORT = ENV['CONTROLLER_PORT'] || Controller::DEFAULT_PORT

UPDATE_TASK_INTERVAL = 10

@tasks = []
@schedule_threads = {}

def update_tasks
  debug("update_tasks()")
  uri = URI("http://#{CONTROLLER_HOST}:#{CONTROLLER_PORT}/tasks.json")
  begin
    res = Net::HTTP.get_response(uri)
    debug("Got response: #{res.code}")
    if res.is_a?(Net::HTTPSuccess)
      new_tasks = JSON.parse(res.body)
      debug("Received #{new_tasks.length} tasks")
      update_task_schedules(new_tasks)
      @tasks = new_tasks
    else
      err("Acquiring tasks failed with status: #{res.code}")
    end
  rescue Errno::ECONNREFUSED
    err("Connection refused")
  rescue => e
    err("Error getting tasks: #{e.message}")
  end
end

def report_result(uuid, result)
  debug("report_result(#{uuid})")
  uri = URI("http://#{CONTROLLER_HOST}:#{CONTROLLER_PORT}/report")
  request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
  request.body = { 
    uuid: uuid,
    result: result, 
    timestamp: Time.now.to_i 
  }.to_json
  begin
    Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
  rescue Errno::ECONNREFUSED
    err("Connection refused while reporting result")
  end
end

def update_task_schedules(new_tasks)
  debug("Updating task schedules...")
  new_task_uuids = new_tasks.map { |task| task['uuid'] }
  debug("New task UUIDs: #{new_task_uuids}")
  
  # remove tasks which are no longer scheduled
  @schedule_threads.keys.each do |uuid|
    unless new_task_uuids.include?(uuid)
      debug("Removing task: #{uuid}")
      @schedule_threads[uuid].kill
      @schedule_threads.delete(uuid)
    end
  end

  # schedule new tasks
  new_tasks.each do |task|
    uuid = task['uuid'].clone
    command = task['command'].clone
    schedule = task['schedule'].clone
    type = task['type'].clone

    if type == 'shell' && !@schedule_threads[uuid]
      debug("Scheduling new shell task: #{uuid} (#{command})")
      @schedule_threads[uuid] = Thread.new do
        loop do
          result = `#{command}`
          report_result(uuid, result)
          sleep schedule.to_i
        end
      end
    end
  end
  debug("Current active tasks: #{@schedule_threads.keys}")
end

def start_executor
  Thread.new do
    loop do
      update_tasks
      sleep UPDATE_TASK_INTERVAL
    end
  end
end

if __FILE__ == $0
  trap('INT') { exit }
  start_executor
  sleep
end
