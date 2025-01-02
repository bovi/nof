require 'webrick'
require 'json'
require 'net/http'
require 'thread'

require_relative 'lib'

CONTROLLER_CONFIG_DIR = ENV['CONTROLLER_CONFIG_DIR'] || Dir.mktmpdir
DASHBOARD_PORT = ENV['DASHBOARD_PORT'] || 1080
DASHBOARD_HOST = ENV['DASHBOARD_HOST'] || 'localhost'
CONTROLLER_PORT = ENV['CONTROLLER_PORT'] || 1880

CONFIG_DIR = CONTROLLER_CONFIG_DIR

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
  uri = URI("http://#{DASHBOARD_HOST}:#{DASHBOARD_PORT}/data/update")
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

def update_config(state)
  uri = URI("http://#{DASHBOARD_HOST}:#{DASHBOARD_PORT}/config/update")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  begin
    if state == :init
      request.body = { type: 'init', tasks: Tasks.all }.to_json
    elsif state == :sync
      request.body = { type: 'sync' }.to_json
    else
      raise ArgumentError, "Invalid state: #{state}"
    end

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      ret = JSON.parse(response.body)
      if ret['message'] == 'ok'
        puts "[#{Time.now}] Updated dashboard config"
      elsif ret['message'] == 'already init'
        puts "[#{Time.now}] Dashboard already initialized"
      elsif ret['message'] == 'sync'
        puts "[#{Time.now}] Synced dashboard activities"
        ret['activities'].each do |activity|
          if activity['type'] == 'delete_task'
            Tasks.remove(activity['uuid'])
            puts "[#{Time.now}] Deleting task: #{activity['uuid']}"
          end
        end
      elsif ret['message'] == 'nothing to sync'
        puts "[#{Time.now}] Nothing to sync"
      else
        puts "[#{Time.now}] Failed to update dashboard config: #{ret['message']}"
      end
    else
      puts "[#{Time.now}] Failed to update dashboard config: #{response.code} #{response.message}"
    end
  rescue Errno::ECONNREFUSED
    puts "[#{Time.now}] Connection to dashboard refused"
  end
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
  init_dir(CONFIG_DIR)

  Tasks.add('ping -c 1 localhost', 30, 'shell')
  Tasks.add('echo "Hello, World!"', 10, 'shell')
  Tasks.add('ls -lah', 20, 'shell')

  Thread.new do
    loop do
      update_data
      sleep 60
    end
  end
  Thread.new do
    update_config(:init)
    loop do
      sleep 10
      update_config(:sync)
    end
  end

  server = WEBrick::HTTPServer.new(:Port => CONTROLLER_PORT)
  server.mount '/', ControllerServlet

  server
end

if __FILE__ == $0
  s = start_controller
  trap('INT') { s.shutdown }
  s.start
end
