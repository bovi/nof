require 'webrick'
require 'net/http'
require 'json'
require 'thread'

$dashboard_updates = []
$mutex = Mutex.new

class DashboardServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    updates = $mutex.synchronize { $dashboard_updates }
    updates = updates.map { |update| "<p>[#{Time.at(update['timestamp'])}] #{update['message']}</p>" }.join
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
          <p>#{updates}</p>
        </body>
      </html>
    HTML
  end

  def do_POST(request, response)
    if request.path == '/update'
      request_body = JSON.parse(request.body)
      updates = JSON.parse(request.body)
      $mutex.synchronize do
        $dashboard_updates = updates['updates']
      end
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = { message: "ok" }.to_json
    else
      response.status = 404
    end
  end
end

def start_dashboard
  port = ENV['DASHBOARD_PORT'] || 1080
  server = WEBrick::HTTPServer.new(Port: port)
  server.mount '/', DashboardServlet
  server
end

if __FILE__ == $0
  s = start_dashboard
  trap('INT') { s.shutdown }
  s.start
end


