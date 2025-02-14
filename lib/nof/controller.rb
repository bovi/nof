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
  NORTHBOUND_SYSTEM = :Dashboard
  SOUTHBOUND_SYSTEM = nil
  SYNC_INTERVAL = 5

  def setup
  end

  register '/' do |req, res|
    res.body = 'Controller Index'
    res.content_type = 'text/plain'
  end

  register '/tasks.json' do |req, res|
    res.body = [
      {
        'uuid' => '550e8400-e29b-41d4-a716-446655440000',
        'type' => 'shell',
        'opts' => {
          'cmd' => 'echo "Hello, World!"',
          'interval' => 10
        }
      }
    ].to_json
    res.content_type = 'application/json'
  end

  register '/jobs.json' do |req, res|
    jobs = []
    Tasks.all.each do |task|
      tt = TaskTemplates[task['tasktemplate_uuid']]
      next if tt.nil?
      jobs << {
        'uuid' => task['uuid'],
        'type' => tt[:type],
        'opts' => tt[:opts]
      }
    end
    res.body = jobs.to_json
    res.content_type = 'application/json'
  end

  register '/report' do |req, res|
    res.body = {"status" => "ok"}.to_json
    res.content_type = 'application/json'
  end
end