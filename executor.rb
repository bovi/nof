require 'json'
require 'net/http'
require 'thread'

CONTROLLER_HOST = ENV['CONTROLLER_HOST'] || 'localhost'
CONTROLLER_PORT = ENV['CONTROLLER_PORT'] || 1880

@tasks = []
@schedule_threads = {}

def acquire_tasks
  puts "[#{Time.now}] Acquire tasks"
  uri = URI("http://#{CONTROLLER_HOST}:#{CONTROLLER_PORT}/tasks")
  begin
    res = Net::HTTP.get_response(uri)
  rescue Errno::ECONNREFUSED
    puts "[#{Time.now}] Connection refused"
    res = nil
  end
  if res.is_a?(Net::HTTPSuccess)
    new_tasks = JSON.parse(res.body)['tasks']
    update_task_schedules(new_tasks)
    @tasks = new_tasks
  else
    puts "[#{Time.now}] Acquiring tasks failed"
  end
end

def report_result(uuid, result)
  uri = URI("http://#{CONTROLLER_HOST}:#{CONTROLLER_PORT}/report")
  request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
  request.body = { uuid: uuid, result: result, timestamp: Time.now.to_i }.to_json
  begin
    Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
  rescue Errno::ECONNREFUSED
    puts "[#{Time.now}] Connection refused while reporting result"
  end
end

def update_task_schedules(new_tasks)
  new_task_uuids = new_tasks.map { |task| task['uuid'] }
  
  # remove tasks which are no longer scheduled
  @schedule_threads.keys.each do |uuid|
    unless new_task_uuids.include?(uuid)
      puts "[#{Time.now}] Removing task: #{uuid}"
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
      puts "[#{Time.now}] Scheduling task: #{uuid}"
      @schedule_threads[uuid] = Thread.new do
        loop do
          result = `#{command}`
          puts "[#{Time.now}] Executed(#{uuid}): #{command}" #, Result: #{result}"
          report_result(uuid, result)
          sleep schedule
        end
      end
    end
  end
end

def start_executor
  Thread.new do
    loop do
      acquire_tasks
      sleep 60 # Fetch tasks every 60 seconds
    end
  end
end

if __FILE__ == $0
  trap('INT') { exit }
  start_executor
  sleep
end
