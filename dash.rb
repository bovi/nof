require 'webrick'
require 'json'
require 'erb'

class DashboardServlet < WEBrick::HTTPServlet::AbstractServlet
  def initialize(server)
    super
    @tasks = []
    @results = []
  end

  def do_GET(request, response)
    case request.path
    when '/', '/index.html'
      response.content_type = 'text/html'
      response.body = generate_html
    when '/api/tasks'
      response.content_type = 'application/json'
      response.body = JSON.generate(@tasks)
    when '/api/results'
      response.content_type = 'application/json'
      response.body = JSON.generate(@results)
    else
      response.status = 404
    end
  end

  def do_POST(request, response)
    case request.path
    when '/api/tasks'
      data = JSON.parse(request.body)
      @tasks << data
      response.status = 201
    when '/api/results'
      data = JSON.parse(request.body)
      @results << data
      response.status = 201
    else
      response.status = 404
    end
  end

  private

  def generate_html
    <<-HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>Task Dashboard</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .container { max-width: 800px; margin: 0 auto; }
            .section { margin-bottom: 20px; }
            table { width: 100%; border-collapse: collapse; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f5f5f5; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Task Dashboard</h1>
            
            <div class="section">
              <h2>Tasks</h2>
              <table>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Status</th>
                </tr>
                <% @tasks.each do |task| %>
                  <tr>
                    <td><%= task['id'] %></td>
                    <td><%= task['name'] %></td>
                    <td><%= task['status'] %></td>
                  </tr>
                <% end %>
              </table>
            </div>

            <div class="section">
              <h2>Results</h2>
              <table>
                <tr>
                  <th>Task ID</th>
                  <th>Result</th>
                  <th>Timestamp</th>
                </tr>
                <% @results.each do |result| %>
                  <tr>
                    <td><%= result['task_id'] %></td>
                    <td><%= result['output'] %></td>
                    <td><%= result['timestamp'] %></td>
                  </tr>
                <% end %>
              </table>
            </div>
          </div>

          <script>
            function refreshData() {
              fetch('/api/tasks')
                .then(response => response.json())
                .then(data => {
                  // Update tasks table
                });

              fetch('/api/results')
                .then(response => response.json())
                .then(data => {
                  // Update results table
                });
            }

            setInterval(refreshData, 5000);
          </script>
        </body>
      </html>
    HTML
  end
end

if $0 == __FILE__
  quiet_mode = ENV['QUIET_MODE']
  server = WEBrick::HTTPServer.new(
    Port: 8080,
    Logger: quiet_mode ? WEBrick::Log.new('/dev/null') : WEBrick::Log.new($stderr),
    AccessLog: quiet_mode ? [] : [[$stderr, "[%{%Y-%m-%d %H:%M:%S}t] %m %U %s %b"]]
  )
  server.mount '/', DashboardServlet
  
  trap('INT') { server.shutdown }
  
  puts "Dashboard started on http://localhost:8080" unless quiet_mode
  server.start
end 