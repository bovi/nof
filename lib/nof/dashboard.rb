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

  register '/' do |req, res|
    res.body = 'Dashboard Home'
    res.content_type = 'text/plain'
  end

  register '/activities.json' do |req, res|
    res.body = Activities.to_json
    res.content_type = 'application/json'
  end

  register '/tasktemplates.json' do |req, res|
    res.body = TaskTemplates.to_json
    res.content_type = 'application/json'
  end

  register '/tasktemplate' do |req, res|
    params = req.query

    _, task_template = Activities.tasktemplate_add(
      cmd: params['cmd'],
      format: params['format']
    )

    res.body = task_template.to_json
    res.content_type = 'application/json'
  end
end
