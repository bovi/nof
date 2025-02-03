require 'webrick'
require 'net/http'
require 'json'
require 'thread'

require_relative 'lib/nof'

DASHBOARD_CONFIG_DIR = ENV['DASHBOARD_CONFIG_DIR'] || Dir.mktmpdir
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
    elsif request.path == '/groups.json'
      json_response(response, Groups.all)
    elsif request.path == '/task_templates.json'
      json_response(response, TaskTemplates.all)
    else
      updates = $mutex.synchronize { $dashboard_updates }
      updates = updates.map { |update| "<p>[#{Time.at(update['timestamp'])}] #{update['message']}</p>" }.join

      # Get all groups for dropdowns
      all_groups = Groups.all
      groups_options = all_groups.map { |g| "<option value='#{g['uuid']}'>#{g['name']}</option>" }.join

      # Task Templates section
      task_templates = TaskTemplates.all.map do |template|
        # Get groups for this template
        template_groups = Groups.get_groups_for_template(template['uuid'])
        group_list = template_groups.map { |g| g['name'] }.join(', ')
        
        <<-HTML
          <tr>
            <td>#{template['uuid']}</td>
            <td>#{template['command']}</td>
            <td>#{template['schedule']}</td>
            <td>#{template['type']}</td>
            <td>#{group_list}</td>
            <td>
              <form action="/config/task_templates/add_group" method="post" style="display: inline;">
                <input type="hidden" name="template_uuid" value="#{template['uuid']}">
                <select name="group_uuid">
                  #{groups_options}
                </select>
                <input type="submit" value="Add to Group">
              </form>
              <form action="/config/task_templates/delete" method="post" style="display: inline;">
                <input type="hidden" name="uuid" value="#{template['uuid']}">
                <input type="submit" value="Delete">
              </form>
            </td>
          </tr>
        HTML
      end.join

      # Hosts section with group assignments
      hosts = Hosts.all.map do |host|
        # Get groups for this host
        host_groups = Groups.get_groups_for_host(host['uuid'])
        group_list = host_groups.map { |g| g['name'] }.join(', ')

        <<-HTML
          <tr>
            <td>#{host['uuid']}</td>
            <td>#{host['name']}</td>
            <td>#{host['ip']}</td>
            <td>#{group_list}</td>
            <td>
              <form action="/config/hosts/add_group" method="post" style="display: inline;">
                <input type="hidden" name="host_uuid" value="#{host['uuid']}">
                <select name="group_uuid">
                  #{groups_options}
                </select>
                <input type="submit" value="Add to Group">
              </form>
              <form action="/config/hosts/delete" method="post" style="display: inline;">
                <input type="hidden" name="uuid" value="#{host['uuid']}">
                <input type="submit" value="Delete">
              </form>
            </td>
          </tr>
        HTML
      end.join

      # Groups section with member counts
      groups = Groups.all.map do |group|
        host_count = Groups.get_host_count(group['uuid'])
        template_count = Groups.get_template_count(group['uuid'])

        <<-HTML
          <tr>
            <td>#{group['uuid']}</td>
            <td>#{group['name']}</td>
            <td>#{host_count} hosts</td>
            <td>#{template_count} templates</td>
            <td>
              <form action="/config/groups/delete" method="post">
                <input type="hidden" name="uuid" value="#{group['uuid']}">
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
                margin-bottom: 20px;
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
              .inline-form {
                display: inline-block;
                margin-right: 10px;
              }
            </style>
          </head>
          <body>
            <h1>Dashboard</h1>
            <p>#{Time.now}</p>
            <p>State: #{Dashboard.state}</p>

            <h2>Task Templates</h2>
            <form action="/config/task_templates/add" method="post">
              <table>
                <tr>
                  <td><input type="text" name="command" placeholder="Command" required></td>
                  <td><input type="text" name="schedule" placeholder="Schedule" required></td>
                  <td><input type="text" name="type" placeholder="Type" required></td>
                  <td>
                    <select name="group_uuids" multiple>
                      #{groups_options}
                    </select>
                  </td>
                  <td><input type="submit" value="Add Template"></td>
                </tr>
              </table>
            </form>
            <table>
              <tr>
                <th>UUID</th>
                <th>Command</th>
                <th>Schedule</th>
                <th>Type</th>
                <th>Groups</th>
                <th>Actions</th>
              </tr>
              #{task_templates}
            </table>

            <h2>Hosts</h2>
            <form action="/config/hosts/add" method="post">
              <table>
                <tr>
                  <td><input type="text" name="name" placeholder="Host Name" required></td>
                  <td><input type="text" name="ip" placeholder="IP Address" required></td>
                  <td>
                    <select name="group_uuids" multiple>
                      #{groups_options}
                    </select>
                  </td>
                  <td><input type="submit" value="Add Host"></td>
                </tr>
              </table>
            </form>
            <table>
              <tr>
                <th>UUID</th>
                <th>Name</th>
                <th>IP</th>
                <th>Groups</th>
                <th>Actions</th>
              </tr>
              #{hosts}
            </table>

            <h2>Groups</h2>
            <form action="/config/groups/add" method="post">
              <table>
                <tr>
                  <td><input type="text" name="name" placeholder="Group Name" required></td>
                  <td><input type="submit" value="Add Group"></td>
                </tr>
              </table>
            </form>
            <table>
              <tr>
                <th>UUID</th>
                <th>Name</th>
                <th>Hosts</th>
                <th>Templates</th>
                <th>Actions</th>
              </tr>
              #{groups}
            </table>

            <h2>Updates</h2>
            <div>#{updates}</div>
          </body>
        </html>
      HTML
    end
  end

  def do_POST(request, response)
    begin
      case request.path
      when '/data/update'
        updates = JSON.parse(request.body)['updates'] || []
        $mutex.synchronize do
          $dashboard_updates = updates
        end
        response.status = 200
        response['Content-Type'] = 'application/json'
        response.body = { message: 'ok' }.to_json

      when '/config/update'
        data = JSON.parse(request.body)
        type = data['type'] || ''
        if type == 'init'
          if Dashboard.state == :init
            debug("re-initializing dashboard")
          end

          TaskTemplates.clean!
          tasks = JSON.parse(request.body)['tasks'] || []
          tasks.each do |task|
            TaskTemplates.add(task['command'], task['schedule'], task['type'], task['group_uuids'] || [], with_uuid: task['uuid'])
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

      when '/config/task_templates/add'
        data = URI.decode_www_form(request.body).to_h
        debug("Adding task template with data: #{data.inspect}")
        command = data['command']
        schedule = data['schedule']
        type = data['type']
        group_uuids = data['group_uuids'].is_a?(Array) ? data['group_uuids'] : [data['group_uuids']].compact

        uuid = TaskTemplates.add(command, schedule, type, group_uuids)
        Activities.add_task_template(uuid, command, schedule, type, group_uuids)

      when '/config/task_templates/add_group'
        data = URI.decode_www_form(request.body).to_h
        template_uuid = data['template_uuid']
        group_uuid = data['group_uuid']
        
        Groups.add_task_template(group_uuid, template_uuid)
        Activities.add_template_to_group(template_uuid, group_uuid)

      when '/config/task_templates/delete'
        data = URI.decode_www_form(request.body).to_h
        uuid = data['uuid']

        TaskTemplates.remove(uuid)
        Activities.delete_task_template(uuid)

      when '/config/hosts/add'
        data = URI.decode_www_form(request.body).to_h
        name = data['name']
        ip = data['ip']
        group_uuids = data['group_uuids'].is_a?(Array) ? data['group_uuids'] : [data['group_uuids']].compact
        debug("Group uuids: #{group_uuids.inspect}")

        uuid = Hosts.add(name, ip)
        group_uuids.each do |group_uuid|
          Groups.add_host(group_uuid, uuid)
          Activities.add_host_to_group(uuid, group_uuid)
        end
        Activities.add_host(uuid, name, ip)

      when '/config/hosts/add_group'
        data = URI.decode_www_form(request.body).to_h
        host_uuid = data['host_uuid']
        group_uuid = data['group_uuid']
        
        Groups.add_host(group_uuid, host_uuid)
        Activities.add_host_to_group(host_uuid, group_uuid)

      when '/config/hosts/delete'
        data = URI.decode_www_form(request.body).to_h
        uuid = data['uuid']

        Hosts.remove(uuid)
        Activities.delete_host(uuid)

      when '/config/groups/add'
        data = URI.decode_www_form(request.body).to_h
        name = data['name']

        debug("Adding group with name: #{name}")

        uuid = Groups.add(name)
        Activities.add_group(uuid, name)

      when '/config/groups/delete'
        data = URI.decode_www_form(request.body).to_h
        uuid = data['uuid']

        Groups.remove(uuid)
        Activities.delete_group(uuid)
      else
        err("Unknown path: #{request.path}")
        response.status = 404
      end

      # Only redirect for form submissions, not API calls
      if request.path.start_with?('/config/') && !request.path.end_with?('/update')
        response.status = 302
        response['Location'] = '/'
      end
    rescue => e
      err("Error in do_POST: #{e.class}: #{e.message}")
      err(e.backtrace.join("\n"))
      response.status = 500
      response.body = "Internal Server Error: #{e.message}"
    end
  end
end

def start_dashboard
  server_config = { Port: DASHBOARD_PORT }
  if log?(3)
    server_config.merge!(
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
  end
  
  debug("Dashboard CONFIG_DIR: #{CONFIG_DIR}")
  DatabaseConfig.setup_all_tables!
  server = WEBrick::HTTPServer.new(server_config)
  server.mount '/', DashboardServlet
  server
end

if __FILE__ == $0
  server = start_dashboard
  trap('INT') do
    DatabaseConfig.close_all_connections
    server.shutdown
  end
  server.start
end


