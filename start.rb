#!/usr/bin/env ruby

require 'json'
require 'net/http'

def start_service(command, name)
  pid = spawn(command)
  puts "Starting #{name} (PID: #{pid})..."
  pid
end

def wait_for_service(name, port)
  print "Waiting for #{name}"
  30.times do  # 15 seconds timeout
    begin
      response = Net::HTTP.get_response(URI("http://localhost:#{port}/"))
      if response.code.to_i < 500
        puts " - Ready"
        return true
      end
    rescue Errno::ECONNREFUSED
      print "."
      sleep 0.5
    end
  end
  puts "\nFailed to start #{name}"
  false
end

def show_usage
  puts "\nSystem is ready! Available endpoints:"
  puts "\nDashboard:"
  puts "  http://localhost:8080 - Web interface"
  puts "\nController API:"
  puts "  GET  http://localhost:8081/tasks.json - List all tasks"
  puts "  POST http://localhost:8081/tasks - Submit a task"
  puts "  GET  http://localhost:8081/results.json - List all results"
  puts "\nExample task submission:"
  puts %q{
  curl -X POST http://localhost:8081/tasks \
       -H "Content-Type: application/json" \
       -d '{
         "uuid": "test1",
         "command": "ls -la",
         "schedule": 5,
         "type": "shell"
       }'
  }
  puts "\nPress Ctrl+C to stop all services"
end

# Start all services
pids = []

# Start controller first
pids << start_service('ruby ctrl.rb', 'Controller')
exit 1 unless wait_for_service('Controller', 8081)

# Start dashboard
pids << start_service('ruby dash.rb', 'Dashboard')
exit 1 unless wait_for_service('Dashboard', 8080)

# Start executor
pids << start_service('ruby exec.rb', 'Executor')

show_usage

# Wait for Ctrl+C
begin
  sleep
rescue Interrupt
  puts "\nShutting down..."
  pids.each do |pid|
    begin
      Process.kill('INT', pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      # Process already gone, ignore
    end
  end
end 