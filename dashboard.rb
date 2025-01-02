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

class Activities
  def initialize
    @activities = []
  end

  def delete_task(uuid)
    @activities << { timestamp: Time.now.to_i, type: 'delete_task', uuid: uuid }
  end

  def all
    @activities
  end
end

class DashboardServlet < WEBrick::HTTPServlet::AbstractServlet
  @state = :init
  @activities = Activities.new
  @mutex = Mutex.new
  class << self
    attr_accessor :state, :mutex, :activities
  end

  def self.dashboard_state
    @mutex.synchronize { @state }
  end

  def self.dashboard_state=(new_state)
    @mutex.synchronize { @state = new_state }
  end

  def self.dashboard_activities
    @mutex.synchronize { @activities.all }
  end

  def self.dashboard_activities_available?
    @mutex.synchronize { @activities.all.any? }
  end

  def self.dashboard_activities_clean!
    @mutex.synchronize { @activities.all.clear }
  end

  def self.delete_task(uuid)
    @mutex.synchronize { @activities.delete_task(uuid) }
  end

  def initialize(server)
    super(server)
  end

  def do_GET(request, response)
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
          <p>State: #{self.class.dashboard_state}</p>
          <h2>Tasks</h2>
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
          <h2>Activities</h2>
          <p>#{self.class.dashboard_activities}</p>
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
        if self.class.dashboard_state == :init
          puts "[#{Time.now}] re-initializing dashboard"
        end

        Tasks.clean!
        tasks = JSON.parse(request.body)['tasks'] || []
        tasks.each do |task|
          Tasks.add(task['command'], task['schedule'], task['type'], with_uuid: task['uuid'])
        end
        self.class.dashboard_state = :synced
        response.status = 200
        response['Content-Type'] = 'application/json'
        response.body = { message: 'ok' }.to_json
      elsif type == 'sync'
        response.status = 200
        response['Content-Type'] = 'application/json'
        if self.class.dashboard_activities_available?
          response.body = { message: 'sync', activities: self.class.dashboard_activities }.to_json
          self.class.dashboard_activities_clean!
        else
          response.body = { message: 'nothing to sync' }.to_json
        end
      else
        response.status = 404
      end
    elsif request.path == '/config/tasks/delete'
      data = URI.decode_www_form(request.body).to_h
      uuid = data['uuid']

      self.class.delete_task(uuid)
      Tasks.remove(uuid)

      # and then redirect to /config/tasks
      response.status = 302
      response['Location'] = '/'
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


