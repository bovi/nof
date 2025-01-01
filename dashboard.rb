require 'webrick'
require 'net/http'
require 'json'
require 'thread'

require_relative 'lib'

DASHBOARD_CONFIG_DIR = ENV['CONTROLLER_CONFIG_DIR'] || Dir.mktmpdir
DASHBOARD_PORT = ENV['DASHBOARD_PORT'] || 1080

CONFIG_DIR = DASHBOARD_CONFIG_DIR

$dashboard_updates = []
$mutex = Mutex.new

class DashboardServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    updates = $mutex.synchronize { $dashboard_updates }
    updates = updates.map { |update| "<p>[#{Time.at(update['timestamp'])}] #{update['message']}</p>" }.join
    tasks = Tasks.all.map { |task| "<tr><td>#{task['uuid']}</td><td>#{task['command']}</td><td>#{task['schedule']}</td><td>#{task['type']}</td></tr>" }.join
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
          <h2>Tasks</h2>
          <table>
            <tr>
              <th>UUID</th>
              <th>Command</th>
              <th>Schedule</th>
              <th>Type</th>
            </tr>
          #{tasks}
          </table>
          <h2>Updates</h2>
          <p>#{updates}</p>
        </body>
      </html>
    HTML
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
        Tasks.clean!
        tasks = JSON.parse(request.body)['tasks'] || []
        tasks.each do |task|
          Tasks.add(task['command'], task['schedule'], task['type'], with_uuid: task['uuid'])
        end
        response.status = 200
        response['Content-Type'] = 'application/json'
        response.body = { message: 'ok' }.to_json
      elsif type == 'sync'
        response.status = 200
        response['Content-Type'] = 'application/json'
        response.body = { activities: Activities.all }.to_json
        Activities.clean!
      else
        response.status = 404
      end
    else
      response.status = 404
    end
  end
end

def init_dir(dir)
  puts "[#{Time.now}] Initializing directory: #{dir}"
  %w[tasks].each do |subdir|
    path = File.join(dir, subdir)
    Dir.mkdir(path) unless Dir.exist?(path)
  end
end

def start_dashboard
  init_dir(CONFIG_DIR)
  server = WEBrick::HTTPServer.new(Port: DASHBOARD_PORT)
  server.mount '/', DashboardServlet
  server
end

if __FILE__ == $0
  s = start_dashboard
  trap('INT') { s.shutdown }
  s.start
end


