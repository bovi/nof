require 'webrick'
require 'net/http'
require 'json'
require 'thread'

require_relative 'lib'
require_relative 'lib/response_helper'

DASHBOARD_CONFIG_DIR = ENV['CONTROLLER_CONFIG_DIR'] || Dir.mktmpdir
DASHBOARD_PORT = ENV['DASHBOARD_PORT'] || Dashboard::DEFAULT_PORT

CONFIG_DIR = DASHBOARD_CONFIG_DIR

$dashboard_updates = []
$mutex = Mutex.new

class DashboardServlet < WEBrick::HTTPServlet::AbstractServlet
  include ResponseHelper

  def initialize(server)
    super(server)
  end

  def do_GET(request, response)
    if request.path == '/version.json'
      json_response(response, Dashboard::VERSION)
    elsif request.path == '/hosts.json'
      json_response(response, Hosts.all)
    else
      updates = $mutex.synchronize { $dashboard_updates }
      updates = updates.map { |update| "<p>[#{Time.at(update['timestamp'])}] #{update['message']}</p>" }.join
      tasks = Tasks.all.map do |task|
        <<-HTML
          <tr>
            <td>#{task['uuid']}</td>
            <td>#{task['command']}</td>
            <td>#{task['schedule']}</td>
            <td>#{task['type']}</td>
            <td>
              <form action="/config/tasks/delete" method="post">
                <input type="hidden" name="uuid" value="#{task['uuid']}">
                <input type="submit" value="Delete">
              </form>
            </td>
          </tr>
        HTML
      end.join

      hosts = Hosts.all.map do |host|
        <<-HTML
          <tr>
            <td>#{host['uuid']}</td>
            <td>#{host['name']}</td>
            <td>#{host['ip']}</td>
            <td>
              <form action="/config/hosts/delete" method="post">
                <input type="hidden" name="uuid" value="#{host['uuid']}">
                <input type="submit" value="Delete">
              </form>
            </td>
          </tr>
        HTML
      end.join

      response.content_type = 'text/html'
      response.body = <<-HTML
        <html>
          <head>
            <title>Dashboard</title>
            <style>
              table {
                border-collapse: collapse;
                width: 100%;
              }
              th, td {
                border: 1px solid #ddd;
                padding: 8px;
                text-align: left;
              }
              th {
                background-color: #f2f2f2;
              }
              tr:nth-child(even) {
                background-color: #f9f9f9;
              }
            </style>
          </head>
          <body>
            <h1>Dashboard</h1>
            <p>#{Time.now}</p>
            <p>State: #{Dashboard.state}</p>
            <h2>Tasks</h2>
            <form action="/config/tasks/add" method="post">
              <table>
                <tr>
                  <td><input type="text" name="command" placeholder="Command" required></td>
                  <td><input type="text" name="schedule" placeholder="Schedule" required></td>
                  <td><input type="text" name="type" placeholder="Type" required></td>
                  <td><input type="submit" value="Add Task"></td>
                </tr>
              </table>
            </form>
            <table>
              <tr>
                <th>UUID</th>
                <th>Command</th>
                <th>Schedule</th>
                <th>Type</th>
                <th>Actions</th>
              </tr>
            #{tasks}
            </table>
            <h2>Hosts</h2>
            <form action="/config/hosts/add" method="post">
              <table>
                <tr>
                  <td><input type="text" name="name" placeholder="Host Name" required></td>
                  <td><input type="text" name="ip" placeholder="IP Address" required></td>
                  <td><input type="submit" value="Add Host"></td>
                </tr>
              </table>
            </form>
            <table>
              <tr>
                <th>UUID</th>
                <th>Name</th>
                <th>IP</th>
                <th>Actions</th>
              </tr>
              #{hosts}
            </table>
            <h2>Activities</h2>
            <p>#{Activities.all}</p>
            <h2>Updates</h2>
            <p>#{updates}</p>
          </body>
        </html>
      HTML
    end
  end

  def do_POST(request, response)
    if request.path == '/data/update'
      updates = JSON.parse(request.body)['updates'] || []
      $mutex.synchronize do
        $dashboard_updates = updates
      end
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = { message: 'ok' }.to_json
    elsif request.path == '/config/update'
      data = JSON.parse(request.body)
      type = data['type'] || ''
      if type == 'init'
        if Dashboard.state == :init
          log("re-initializing dashboard")
        end

        Tasks.clean!
        tasks = JSON.parse(request.body)['tasks'] || []
        tasks.each do |task|
          Tasks.add(task['command'], task['schedule'], task['type'], with_uuid: task['uuid'])
        end
        Dashboard.state = :synced
        response.status = 200
        response['Content-Type'] = 'application/json'
        response.body = { message: 'ok' }.to_json
      elsif type == 'sync'
        response.status = 200
        response['Content-Type'] = 'application/json'
        if Activities.any?
          response.body = { message: 'sync', activities: Activities.all }.to_json
          Activities.clean!
        else
          response.body = { message: 'nothing to sync' }.to_json
        end
      else
        response.status = 404
      end
    elsif request.path == '/config/tasks/delete'
      data = URI.decode_www_form(request.body).to_h
      uuid = data['uuid']

      Tasks.remove(uuid)
      Activities.delete_task(uuid)

      # and then redirect to /config/tasks
      response.status = 302
      response['Location'] = '/'
    elsif request.path == '/config/tasks/add'
      data = URI.decode_www_form(request.body).to_h
      command = data['command']
      schedule = data['schedule']
      type = data['type']

      uuid = Tasks.add(command, schedule, type)
      Activities.add_task(uuid, command, schedule, type)

      response.status = 302
      response['Location'] = '/'
    elsif request.path == '/config/hosts/delete'
      data = URI.decode_www_form(request.body).to_h
      uuid = data['uuid']

      Hosts.remove(uuid)
      Activities.delete_host(uuid)

      response.status = 302
      response['Location'] = '/'
    elsif request.path == '/config/hosts/add'
      data = URI.decode_www_form(request.body).to_h
      name = data['name']
      ip = data['ip']

      uuid = Hosts.add(name, ip)
      Activities.add_host(uuid, name, ip)

      response.status = 302
      response['Location'] = '/'
    else
      response.status = 404
    end
  end
end

def init_dir(dir)
  log("Initializing directory: #{dir}")
  %w[tasks activities hosts].each do |subdir|
    path = File.join(dir, subdir)
    Dir.mkdir(path) unless Dir.exist?(path)
  end
  Dashboard.state = :init
end

def start_dashboard
  init_dir(CONFIG_DIR)
  
  server_config = { Port: DASHBOARD_PORT }
  if ENV['DISABLE_LOGGING']
    server_config.merge!(
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
  end
  
  server = WEBrick::HTTPServer.new(server_config)
  server.mount '/', DashboardServlet
  server
end

if __FILE__ == $0
  s = start_dashboard
  trap('INT') { s.shutdown }
  s.start
end


