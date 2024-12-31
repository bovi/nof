require 'webrick'
require 'json'

class ExecutorServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_POST(request, response)
    if request.path == '/shell'
      request_body = JSON.parse(request.body)
      command = request_body['command']
      result = `#{command}`

      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = { result: result }.to_json
    else
      response.status = 404
    end
  end
end

if __FILE__ == $0
  port = ENV['EXECUTOR_PORT'] || 2080
  server = WEBrick::HTTPServer.new(:Port => port)
  server.mount '/execute', ExecutorServlet

  trap('INT') { server.shutdown }
  server.start
end
