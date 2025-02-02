require 'webrick'
require 'json'
require 'net/http'
require 'thread'

require_relative 'lib/nof'

CONTROLLER_CONFIG_DIR = ENV['CONTROLLER_CONFIG_DIR'] || Dir.mktmpdir
DASHBOARD_PORT = ENV['DASHBOARD_PORT']&.to_i || Dashboard::DEFAULT_PORT
DASHBOARD_HOST = ENV['DASHBOARD_HOST'] || 'localhost'
CONTROLLER_PORT = ENV['CONTROLLER_PORT']&.to_i || Controller::DEFAULT_PORT

UPDATE_DATA_INTERVAL = ENV['CONTROLLER_UPDATE_DATA_INTERVAL']&.to_i || 10
UPDATE_CONFIG_INTERVAL = ENV['CONTROLLER_UPDATE_CONFIG_INTERVAL']&.to_i || 10

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
      log("Failed to update dashboard: #{response.code} #{response.message}")
    else
      $controller_updates.clean!
    end
  rescue Errno::ECONNREFUSED
    log("Connection to dashboard refused")
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
        log("Updated dashboard config")
      elsif ret['message'] == 'already init'
        log("Dashboard already initialized")
      elsif ret['message'] == 'sync'
        log("Synced dashboard activities")
        ret['activities'].each do |activity|
          case activity['type']
          when 'delete_task'
            Tasks.remove(activity['opt']['uuid'])
            log("Deleting task: #{activity['opt']['uuid']}")
          when 'add_task'
            uuid = Tasks.add(activity['opt']['command'], activity['opt']['schedule'], activity['opt']['type'], with_uuid: activity['opt']['uuid'])
            log("Adding task: #{uuid}")
          when 'delete_host'
            Hosts.remove(activity['opt']['uuid'])
            log("Deleting host: #{activity['opt']['uuid']}")
          when 'add_host'
            uuid = Hosts.add(activity['opt']['name'], activity['opt']['ip'], with_uuid: activity['opt']['uuid'])
            log("Adding host: #{uuid}")
          else
            log("Unknown activity: #{activity}")
          end
        end
      elsif ret['message'] == 'nothing to sync'
        log("Nothing to sync")
      else
        log("Failed to update dashboard config: #{ret['message']}")
      end
    else
      log("Failed to update dashboard config: #{response.code} #{response.message}")
    end
  rescue Errno::ECONNREFUSED
    log("Connection to dashboard refused")
  end
end

class ControllerServlet < WEBrick::HTTPServlet::AbstractServlet
  include ResponseHelper
  
  def do_GET(request, response)
    if request.path == '/version.json'
      json_response(response, Controller::VERSION)
    elsif request.path == '/tasks.json'
      json_response(response, Tasks.all)
    elsif request.path == '/hosts.json'
      json_response(response, Hosts.all)
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
  log("Initializing directory: #{dir}")
  %w[tasks results hosts].each do |subdir|
    path = File.join(dir, subdir)
    Dir.mkdir(path) unless Dir.exist?(path)
  end
end

def start_controller
  init_dir(CONFIG_DIR)

  Thread.new do
    loop do
      update_data
      sleep UPDATE_DATA_INTERVAL
    end
  end
  Thread.new do
    update_config(:init)
    loop do
      sleep UPDATE_CONFIG_INTERVAL
      update_config(:sync)
    end
  end

  server_config = { Port: CONTROLLER_PORT }
  if ENV['DISABLE_LOGGING']
    server_config.merge!(
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
  end
  
  server = WEBrick::HTTPServer.new(server_config)
  server.mount '/', ControllerServlet

  server
end

if __FILE__ == $0
  s = start_controller
  trap('INT') { s.shutdown }
  s.start
end
