# Start all server processes
server_pids = %w[dash rash ctrl exec].map { |server| spawn("ruby #{server}.rb") }

# Give the servers a moment to start
sleep(2)

# Set up graceful shutdown
running = true
trap('INT') do
  running = false
  server_pids.each do |pid|
    begin
      Process.kill('INT', pid)
      Process.wait(pid)
    rescue Errno::ESRCH
      # Process already terminated
    end
  end
  exit
end

# Keep the main process running
while running
  sleep(1)
end
