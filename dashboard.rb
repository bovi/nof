require 'webrick'
require 'net/http'
require 'json'

class DashboardServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    controller_port = ENV['CONTROLLER_PORT'] || 1880
    uri_data = URI("http://localhost:#{controller_port}/data")
    uri_ping = URI("http://localhost:#{controller_port}/ping")

    res_data = Net::HTTP.get_response(uri_data)
    data = res_data.is_a?(Net::HTTPSuccess) ? JSON.parse(res_data.body)['data'] : "Error fetching data"

    res_ping = Net::HTTP.get_response(uri_ping)
    ping_result = res_ping.is_a?(Net::HTTPSuccess) ? JSON.parse(res_ping.body)['result'] : "Error executing ping"

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
          <p>Data from controller: #{data}</p>
          <p>Ping result: #{ping_result}</p>
          <table>
            <thead>
              <tr>
                <th>Header 1</th>
                <th>Header 2</th>
                <th>Header 3</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Data 1</td>
                <td>Data 2</td>
                <td>Data 3</td>
              </tr>
              <tr>
                <td>Data 4</td>
                <td>Data 5</td>
                <td>Data 6</td>
              </tr>
            </tbody>
          </table>
        </body>
      </html>
    HTML
  end
end

if __FILE__ == $0
  port = ENV['DASHBOARD_PORT'] || 1080
  server = WEBrick::HTTPServer.new(Port: port)
  server.mount '/', DashboardServlet
  trap('INT') { server.shutdown }
  server.start
end


