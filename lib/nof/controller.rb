require_relative 'system'

# The controller holds all configurations in the
# systems. It provides a HTTP interface to provide
# a task list to the Executor. Furthermore it
# interacts with the Dashboard to syncronize
# the activities performed by the Dashboard
# and Remote Dashboard. Furthermore it reports
# the collected data from the Executor to the
# Dashboard.
class Controller < System
  PORT = 8070

  register '/' do |req, res|
    res.body = 'Controller Index'
    res.content_type = 'text/plain'
  end

  register '/tasks.json' do |req, res|
    res.body = '[]'
    res.content_type = 'application/json'
  end
end