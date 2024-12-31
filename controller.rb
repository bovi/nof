require 'webrick'
require 'json'
require 'net/http'

class DataController < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    if request.path == '/data'
      response.status = 200
      response['Content-Type'] = 'application/json'
      # Replace with actual data acquisition logic
      response.body = { data: "test" }.to_json
    elsif request.path == '/version'
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = { version: "0.1" }.to_json
    elsif request.path == '/ping'
      executor_port = ENV['EXECUTOR_PORT'] || 2080
      uri = URI("http://localhost:#{executor_port}/shell")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
      request.body = { command: 'ping -c 1 localhost' }.to_json
      res = http.request(request)
      result = res.is_a?(Net::HTTPSuccess) ? JSON.parse(res.body)['result'] : "Error executing ping"

      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = { result: result }.to_json
    else
      response.status = 404
    end
  end
end

if __FILE__ == $0
  port = ENV['CONTROLLER_PORT'] || 1880
  server = WEBrick::HTTPServer.new(:Port => port)
  server.mount '/data', DataController

  trap('INT') { server.shutdown }
  server.start
end
