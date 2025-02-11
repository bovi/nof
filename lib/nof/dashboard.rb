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
  SYNC_INTERVAL = 5

  def setup
  end

  register '/activities/sync' do |req, res|
    status = 'ko'
    message = ''
    activities = []
    begin
      new_activities = JSON.parse(req.body)
      synced_num = Activities.sync(new_activities, from: :southbound)
      status = 'ok'
      message = "Activities synced successfully: #{synced_num}"
      activities = Activities.southbound_raw!
    rescue => e
      err "Sync failed: #{e.message}"
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
    res.body = 'Dashboard Home'
    res.content_type = 'text/plain'
  end

  register '/tasktemplate' do |req, res|
    params = req.query

    _, task_template = Activities.tasktemplate_add(
      type: params['type'],
      cmd: params['cmd'],
      format: {
        pattern: params['pattern'],
        template: params['template']
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
    Activities.tasktemplate_delete(uuid: params['uuid'])
    
    if params['return_url']
      res.status = 302
      res['Location'] = params['return_url']
    else
      res.status = 200
    end
  end

  register '/tasktemplates.html' do |req, res|
    template = File.read(File.join(__dir__, 'views', 'tasktemplate.erb'))
    res.body = ERB.new(template).result(binding)
    res.content_type = 'text/html'
  end
end
