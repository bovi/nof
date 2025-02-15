require_relative 'system'

# The Dashboard is the local user interface.
# It provides a HTTP interface to the user
# and the Controller.
# The user can modify the configurations
# of the system. The Controller can acquire
# these changes or push it's own changes
# to the Dashboard.
# The Dashboard is connecting to the
# Remote Dashboard via a HTTP interface
# to syncronize it's activities.
class Dashboard < System
  PORT = 8080
  NORTHBOUND_SYSTEM = :RemoteDashboard
  SOUTHBOUND_SYSTEM = :Controller
  SYNC_INTERVAL = 5

  def setup
  end

  class << self
    def render(template)
      @content = ERB.new(File.read(File.join(__dir__, 'views', "#{template}.erb"))).result(binding)
      ERB.new(File.read(File.join(__dir__, 'views', '_layout.erb'))).result(binding)
    end
  end

  register '/activities/sync' do |req, res|
    status = 'ko'
    message = ''
    activities = []
    begin
      new_activities = JSON.parse(req.body)
      synced_num = Activities.sync(new_activities, sync_source: :southbound)
      status = 'ok'
      message = "Activities synced successfully: #{synced_num}"
      activities = Activities.southbound_raw!
      info "Synced #{synced_num} activities successfully" unless synced_num.zero?
    rescue => e
      err "Sync failed: #{e.class}: #{e.message}"
      status = 'error'
      message = e.message
    end
    res.body = {
      'status' => status,
      'message' => message,
      'activities' => activities
    }.to_json
    res.content_type = 'application/json'
    res.status = status == 'ok' ? 200 : 500
  end

  register '/' do |req, res|
    res.body = render('index')
    res.content_type = 'text/html'
  end

  register '/tasktemplate' do |req, res|
    params = req.query
    _, task_template = Activities.tasktemplate_add(
      'type' => params['type'],
      'opts' => {
        'cmd' => params['cmd'],
        'format' => {
          'pattern' => params['pattern'],
          'template' => params['template']
        }
      }
    )

    if params['return_url']
      res.status = 302
      res['Location'] = params['return_url']
    else
      res.body = task_template.to_json
      res.content_type = 'application/json'
    end
  end

  register '/tasktemplate/delete' do |req, res|
    params = req.query
    Activities.tasktemplate_delete('uuid' => params['uuid'])
    if params['return_url']
      res.status = 302
      res['Location'] = params['return_url']
    else
      res.status = 200
    end
  end

  register '/tasktemplates.html' do |req, res|
    res.body = render('tasktemplate')
    res.content_type = 'text/html'
  end

  register '/hosts.json' do |req, res|
    hosts = Hosts.all
    res.body = hosts.to_json
    res.content_type = 'application/json'
  end

  register '/host' do |req, res|
    params = req.query
    _, host = Activities.host_add('hostname' => params['hostname'], 'ip' => params['ip'])
    if params['return_url']
      res.status = 302
      res['Location'] = params['return_url']
    else
      res.body = host.to_json
      res.content_type = 'application/json'
    end
  end

  register '/host/delete' do |req, res|
    params = req.query
    Activities.host_delete('uuid' => params['uuid'])
    if params['return_url']
      res.status = 302
      res['Location'] = params['return_url']
    else
      res.status = 200
    end
  end

  register '/hosts.html' do |req, res|
    res.body = render('host')
    res.content_type = 'text/html'
  end

  register '/activities.html' do |req, res|
    res.body = render('activities')
    res.content_type = 'text/html'
  end

  register '/tasks.json' do |req, res|
    tasks = Tasks.all
    res.body = tasks.to_json
    res.content_type = 'application/json'
  end

  register '/task' do |req, res|
    params = req.query
    host = Hosts[params['host_uuid']]
    tasktemplate = TaskTemplates[params['tasktemplate_uuid']]

    if !host || !tasktemplate
      res.status = 500
      res.body = {error: "Host or tasktemplate not found"}.to_json
    else
      _, task = Activities.task_add('host_uuid' => params['host_uuid'], 'tasktemplate_uuid' => params['tasktemplate_uuid'])
      if params['return_url']
        res.status = 302
        res['Location'] = params['return_url']
      else
        res.status = 200
        res.body = task.to_json
        res.content_type = 'application/json'
      end
    end
  end
 
  register '/task/delete' do |req, res|
    params = req.query
    Activities.task_delete('uuid' => params['uuid'])
    if params['return_url']
      res.status = 302
      res['Location'] = params['return_url']
    else
      res.status = 200
    end
  end
end
