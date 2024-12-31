require 'webrick'
require 'json'
require 'securerandom'
require 'net/http'
require 'thread'

class Tasks
  def initialize
    @tasks = []
    @mutex = Mutex.new
  end

  def all
    @mutex.synchronize { @tasks }
  end

  def add(command, schedule, type)
    @mutex.synchronize do
      @tasks << { uuid: SecureRandom.uuid, command: command, schedule: schedule, type: type }
    end
  end

  def remove(uuid)
    @mutex.synchronize do
      @tasks.delete_if { |task| task[:uuid] == uuid }
    end
  end

  def add_result(uuid, result, timestamp)
    @mutex.synchronize do
      task = @tasks.find { |task| task[:uuid] == uuid }
      if task
        task[:results] ||= []
        task[:results] << { result: result, timestamp: timestamp }
      else
        puts "[#{Time.now}] Task #{uuid} not found"
      end
    end
  end
end

class Updates
  def initialize
    @updates = []
    @mutex = Mutex.new
  end

  def all
    @mutex.synchronize { @updates }
  end

  def add(message)
    @mutex.synchronize do
      @updates << { message: message, timestamp: Time.now.to_i }
    end
  end

  def clean!
    @mutex.synchronize do
      @updates = []
    end
  end
end

$controller_updates = Updates.new

$executor_tasks = Tasks.new
$executor_tasks.add('ping -c 1 localhost', 30, 'shell')
$executor_tasks.add('echo "Hello, World!"', 10, 'shell')
$executor_tasks.add('ls -lah', 20, 'shell')

DASHBOARD_PORT = ENV['DASHBOARD_PORT'] || 1080

def update_data
  uri = URI("http://localhost:#{DASHBOARD_PORT}/update")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  request.body = { updates: $controller_updates.all }.to_json
  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    puts "Failed to update dashboard: #{response.code} #{response.message}"
  else
    $controller_updates.clean!
  end
end

def acquire_config
end

class ControllerServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    if request.path == '/data'
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = { data: "test" }.to_json
    elsif request.path == '/version'
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = { version: "0.1" }.to_json
    elsif request.path == '/tasks'
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = { tasks: $executor_tasks.all }.to_json
    else
      response.status = 404
    end
  end

  def do_POST(request, response)
    if request.path == '/report'
      response.status = 200
      response['Content-Type'] = 'application/json'
      request_body = JSON.parse(request.body)
      uuid = request_body['uuid']
      result = request_body['result']
      timestamp = request_body['timestamp']
      $executor_tasks.add_result(uuid, result, timestamp)
      $controller_updates.add("Task #{uuid} reported result: #{result}")
      response.body = { message: "ok" }.to_json
    else
      response.status = 404
    end
  end
end

def start_controller
  Thread.new do
    loop do
      update_data
      sleep 60
    end
  end

  port = ENV['CONTROLLER_PORT'] || 1880
  server = WEBrick::HTTPServer.new(:Port => port)
  server.mount '/', ControllerServlet

  server
end

if __FILE__ == $0
  s = start_controller
  trap('INT') { s.shutdown }
  s.start
end
