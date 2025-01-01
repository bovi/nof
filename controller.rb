require 'webrick'
require 'json'
require 'securerandom'
require 'net/http'
require 'thread'

CONTROLLER_CONFIG_DIR = ENV['CONTROLLER_CONFIG_DIR'] || Dir.mktmpdir
DASHBOARD_PORT = ENV['DASHBOARD_PORT'] || 1080

class Tasks
  def self.all
    # iterate over all files in the tasks directory
    # and return the contents as an array of tasks
    tasks = []
    Dir.glob(File.join(CONTROLLER_CONFIG_DIR, 'tasks', '*')).each do |task_file|
      task = JSON.parse(File.read(task_file))
      task['uuid'] = File.basename(task_file)
      tasks << task
    end
    tasks
  end

  def self.add(command, schedule, type)
    # create a new task file in the tasks directory
    # with the given command, schedule, and type
    uuid = SecureRandom.uuid
    task = { command: command, schedule: schedule, type: type }
    File.write(File.join(CONTROLLER_CONFIG_DIR, 'tasks', uuid), task.to_json)
  end

  def self.remove(uuid)
    # remove the task file with the given uuid
    File.delete(File.join(CONTROLLER_CONFIG_DIR, 'tasks', uuid))
  end

  def self.add_result(uuid, result, timestamp)
    task_result_dir = File.join(CONTROLLER_CONFIG_DIR, 'results', uuid)
    Dir.mkdir(task_result_dir) unless Dir.exist?(task_result_dir)
    task_result_file = File.join(task_result_dir, timestamp.to_s)
    File.write(task_result_file, result)
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


def update_data
  uri = URI("http://localhost:#{DASHBOARD_PORT}/update")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  request.body = { updates: $controller_updates.all }.to_json
  begin
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      puts "[#{Time.now}] Failed to update dashboard: #{response.code} #{response.message}"
    else
      $controller_updates.clean!
    end
  rescue Errno::ECONNREFUSED
    puts "[#{Time.now}] Connection to dashboard refused"
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
      response.body = { tasks: Tasks.all }.to_json
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
      Tasks.add_result(uuid, result, timestamp)
      $controller_updates.add("Task #{uuid} reported result: #{result}")
      response.body = { message: "ok" }.to_json
    else
      response.status = 404
    end
  end
end

def init_dir(dir)
  puts "[#{Time.now}] Initializing directory: #{dir}"
  %w[tasks results].each do |subdir|
    path = File.join(dir, subdir)
    Dir.mkdir(path) unless Dir.exist?(path)
  end
end

def start_controller
  port = ENV['CONTROLLER_PORT'] || 1880
  init_dir(CONTROLLER_CONFIG_DIR)

  Tasks.add('ping -c 1 localhost', 30, 'shell')
  Tasks.add('echo "Hello, World!"', 10, 'shell')
  Tasks.add('ls -lah', 20, 'shell')

  Thread.new do
    loop do
      update_data
      sleep 60
    end
  end

  server = WEBrick::HTTPServer.new(:Port => port)
  server.mount '/', ControllerServlet

  server
end

if __FILE__ == $0
  s = start_controller
  trap('INT') { s.shutdown }
  s.start
end
