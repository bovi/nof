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
        
        # First pass: Create/delete base entities
        ret['activities'].each do |activity|
          case activity['type']
          when 'add_host'
            uuid = Hosts.add(activity['opt']['name'], activity['opt']['ip'], with_uuid: activity['opt']['uuid'])
            log("Adding host: #{uuid}")
          when 'add_group'
            uuid = Groups.add(activity['opt']['name'], with_uuid: activity['opt']['uuid'])
            log("Adding group: #{uuid}")
          when 'add_task_template'
            uuid = TaskTemplates.add(
              activity['opt']['command'],
              activity['opt']['schedule'],
              activity['opt']['type'],
              activity['opt']['group_uuids'],
              with_uuid: activity['opt']['uuid']
            )
            log("Adding task template: #{uuid}")
          when 'delete_host'
            Hosts.remove(activity['opt']['uuid'])
            log("Deleting host: #{activity['opt']['uuid']}")
          when 'delete_group'
            Groups.remove(activity['opt']['uuid'])
            log("Deleting group: #{activity['opt']['uuid']}")
          when 'delete_task_template'
            TaskTemplates.remove(activity['opt']['uuid'])
            log("Deleting task template: #{activity['opt']['uuid']}")
          end
        end

        # Second pass: Create relationships
        ret['activities'].each do |activity|
          case activity['type']
          when 'add_host_to_group'
            begin
              Groups.add_host(
                activity['opt']['group_uuid'],
                activity['opt']['host_uuid']
              )
              log("Adding host #{activity['opt']['host_uuid']} to group #{activity['opt']['group_uuid']}")
            rescue SQLite3::ConstraintException => e
              log("Failed to add host to group: #{e.message}")
            end
          when 'add_template_to_group'
            begin
              Groups.add_task_template(
                activity['opt']['group_uuid'],
                activity['opt']['template_uuid']
              )
              log("Adding template #{activity['opt']['template_uuid']} to group #{activity['opt']['group_uuid']}")
            rescue SQLite3::ConstraintException => e
              log("Failed to add template to group: #{e.message}")
            end
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
      # Expand task templates into specific tasks for each host
      tasks = []
      log("Getting tasks for all hosts...")
      
      Hosts.all.each do |host|
        log("Getting tasks for host: #{host['name']} (#{host['uuid']})")
        host_tasks = TaskTemplates.get_tasks_for_host(host['uuid'])
        log("Found #{host_tasks.length} tasks for host #{host['name']}")
        
        host_tasks.each do |task|
          tasks << {
            'uuid' => "#{task['uuid']}_#{host['uuid']}", # Combine template and host UUIDs
            'command' => task['command'],
            'schedule' => task['schedule'],
            'type' => task['type']
          }
        end
      end
      
      log("Returning #{tasks.length} total tasks")
      json_response(response, tasks)
    elsif request.path == '/hosts.json'
      json_response(response, Hosts.all)
    elsif request.path == '/groups.json'
      json_response(response, Groups.all)
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
      
      # Extract template_uuid and host_uuid from the combined uuid
      template_uuid, host_uuid = uuid.split('_')
     
      # check if host still exists
      host = Hosts.get(host_uuid)
      if host.nil?
        log("Host #{host_uuid} not found, skipping task #{template_uuid}")
        response.body = { message: "host not found" }.to_json
        return
      end

      # check if template still exists
      template = TaskTemplates.get(template_uuid)
      if template.nil?
        log("Template #{template_uuid} not found, skipping task #{template_uuid}")
        response.body = { message: "template not found" }.to_json
        return
      end

      TaskTemplates.add_result(template_uuid, host_uuid, result, timestamp)
      $controller_updates.add("Task #{template_uuid} for host #{host_uuid} reported result: #{result}")
      response.body = { message: "ok" }.to_json
    else
      response.status = 404
    end
  end
end

def start_controller
  log("Controller CONFIG_DIR: #{CONFIG_DIR}")
  DatabaseConfig.setup_all_tables!
  
  update_data_thread = Thread.new do
    begin
      loop do
        update_data
        sleep UPDATE_DATA_INTERVAL
      end
    ensure
      DatabaseConfig.close_all_connections
    end
  end

  update_config_thread = Thread.new do
    begin
      update_config(:init)
      loop do
        sleep UPDATE_CONFIG_INTERVAL
        update_config(:sync)
      end
    ensure
      DatabaseConfig.close_all_connections
    end
  end

  server_config = { Port: CONTROLLER_PORT }
  if ENV['NOF_LOGGING']&.to_i == 0
    server_config.merge!(
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
  end
  
  server = WEBrick::HTTPServer.new(server_config)
  server.mount '/', ControllerServlet

  # Return both server and threads for cleanup
  [server, update_data_thread, update_config_thread]
end

if __FILE__ == $0
  server, update_data_thread, update_config_thread = start_controller
  trap('INT') do 
    update_data_thread.kill
    update_config_thread.kill
    DatabaseConfig.close_all_connections
    server.shutdown
  end
  server.start
end
