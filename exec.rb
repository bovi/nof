require 'json'
require 'net/http'
require 'time'
require 'open3'

class Executor
  CONTROLLER_HOST = 'localhost'
  CONTROLLER_PORT = 8081
  POLL_INTERVAL = 5 # seconds

  def initialize
    @running = true
  end

  def start
    debug "Starting executor..."
    while @running
      fetch_and_execute_tasks
      sleep POLL_INTERVAL
    end
  end

  def stop
    debug "\nStopping executor..."
    @running = false
  end

  private

  def fetch_and_execute_tasks
    tasks = fetch_tasks
    tasks.each do |task|
      execute_task(task)
    end
  rescue => e
    debug "Error: #{e.message}"
  end

  def fetch_tasks
    uri = URI("http://#{CONTROLLER_HOST}:#{CONTROLLER_PORT}/tasks.json")
    response = Net::HTTP.get_response(uri)
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      debug "Failed to fetch tasks: #{response.code} #{response.message}"
      []
    end
  rescue => e
    debug "Error fetching tasks: #{e.message}"
    []
  end

  def execute_task(task)
    debug "Executing task: #{task['command']}"
    
    begin
      output, status = Open3.capture2e(task['command'])
      
      report_result(task['uuid'], output)
    rescue => e
      report_result(task['uuid'], e.message)
    end
  end

  def report_result(task_uuid, output)
    uri = URI("http://#{CONTROLLER_HOST}:#{CONTROLLER_PORT}/report")
    http = Net::HTTP.new(uri.host, uri.port)
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = {
      uuid: task_uuid,
      result: output,
      timestamp: Time.now.iso8601
    }.to_json

    response = http.request(request)
    
    unless response.is_a?(Net::HTTPSuccess)
      debug "Failed to report result: #{response.code} #{response.message}"
    end
  rescue => e
    debug "Error reporting result: #{e.message}"
  end

  def debug(msg)
    puts msg unless ENV['QUIET_MODE']
  end
end

if $0 == __FILE__
  executor = Executor.new
  
  trap('INT') do
    executor.stop
  end
  
  executor.start
end 