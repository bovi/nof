require 'webrick'
require 'json'
require 'time'

class ControllerServlet < WEBrick::HTTPServlet::AbstractServlet
  @@tasks = []    # Use class variables to persist data
  @@results = []  # across requests

  def initialize(server)
    super
  end

  def do_GET(request, response)
    case request.path
    when '/'
      response.status = 200
      response.content_type = 'text/plain'
      response.body = 'Controller is running'
    when '/tasks.json'
      debug "Current tasks: #{@@tasks.inspect}"
      response.status = 200
      response.content_type = 'application/json'
      response.body = JSON.generate(@@tasks)
    when '/results.json'
      debug "Current results: #{@@results.inspect}"
      response.status = 200
      response.content_type = 'application/json'
      response.body = JSON.generate(@@results)
    else
      response.status = 404
    end
  end

  def do_POST(request, response)
    begin
      case request.path
      when '/tasks'
        data = JSON.parse(request.body)
        debug "Received task: #{data.inspect}"
        @@tasks << data
        debug "Updated tasks: #{@@tasks.inspect}"
        response.status = 201
      when '/report'
        data = JSON.parse(request.body)
        debug "Received result: #{data.inspect}"
        @@results << {
          'task_id' => data['uuid'],
          'output' => data['result'],
          'timestamp' => data['timestamp']
        }
        debug "Updated results: #{@@results.inspect}"
        response.status = 200
        response.content_type = 'application/json'
        response.body = JSON.generate({ message: 'ok' })
      else
        response.status = 404
      end
    rescue JSON::ParserError => e
      debug "JSON parsing error: #{e.message}"
      response.status = 400
      response.content_type = 'application/json'
      response.body = JSON.generate({ error: 'Invalid JSON' })
    rescue => e
      debug "Error: #{e.class} - #{e.message}"
      response.status = 500
      response.content_type = 'application/json'
      response.body = JSON.generate({ error: 'Internal server error' })
    end
  end

  private

  def debug(msg)
    puts msg unless ENV['QUIET_MODE']
  end
end

if $0 == __FILE__
  quiet_mode = ENV['QUIET_MODE']
  server = WEBrick::HTTPServer.new(
    Port: 8081,
    Logger: quiet_mode ? WEBrick::Log.new('/dev/null') : WEBrick::Log.new($stderr),
    AccessLog: quiet_mode ? [] : [[$stderr, "[%{%Y-%m-%d %H:%M:%S}t] %m %U %s %b"]]
  )
  server.mount '/', ControllerServlet
  
  trap('INT') { server.shutdown }
  
  puts "Controller started on http://localhost:8081" unless quiet_mode
  server.start
end 