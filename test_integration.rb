require 'minitest/autorun'
require 'net/http'
require 'json'
require 'timeout'

class IntegrationTest < Minitest::Test
  DASH_PORT = 8080
  CTRL_PORT = 8081

  def setup
    debug "\nStarting services..."
    
    # Start controller first since others depend on it
    @ctrl_pid = spawn('ruby ctrl.rb')
    wait_for_service('Controller', CTRL_PORT)

    # Start dashboard
    @dash_pid = spawn('ruby dash.rb')
    wait_for_service('Dashboard', DASH_PORT)

    # Start executor last
    @exec_pid = spawn('ruby exec.rb')
    
    # Give services a moment to fully initialize
    sleep 2
    debug "All services started successfully"
  end

  def teardown
    debug "\nShutting down services..."
    [@dash_pid, @ctrl_pid, @exec_pid].each do |pid|
      begin
        Process.kill('INT', pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        # Process already gone, ignore
      end
    end
  end

  def test_basic_task_execution
    debug "\nSubmitting test task..."
    # Create a simple task
    task = {
      'uuid' => 'test_task_1',
      'command' => 'ls -la',
      'schedule' => 5,
      'type' => 'shell'
    }

    # Submit task to controller
    uri = URI("http://localhost:#{CTRL_PORT}/tasks")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = task.to_json

    response = http.request(request)
    assert_equal 201, response.code.to_i, "Task submission failed"

    # Verify task was received
    uri = URI("http://localhost:#{CTRL_PORT}/tasks.json")
    response = Net::HTTP.get_response(uri)
    tasks = JSON.parse(response.body)
    assert_equal 1, tasks.length, "Task not found in controller"

    debug "Waiting for task execution..."
    # Wait for task execution and result
    results = nil
    Timeout.timeout(10) do
      loop do
        uri = URI("http://localhost:#{CTRL_PORT}/results.json")
        response = Net::HTTP.get_response(uri)
        results = JSON.parse(response.body)
        break if !results.empty?
        debug "." if ENV['QUIET_MODE'].nil?
        sleep 1
      end
    end
    debug "Results received"

    # Verify results
    refute_empty results, "No results received"
    result = results.first
    assert_equal task['uuid'], result['task_id']
    refute_empty result['output']
    assert result['timestamp']
  end

  private

  def wait_for_service(name, port)
    debug_no_newline "Waiting for #{name}"
    Timeout.timeout(10) do
      loop do
        begin
          response = Net::HTTP.get_response(URI("http://localhost:#{port}/"))
          if response.code.to_i < 500
            debug " - Ready"
            break
          end
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET
          debug_no_newline "."
          sleep 0.5
        end
      end
    end
  rescue Timeout::Error
    debug "\nFailed to start #{name} within timeout"
    raise
  end

  def debug(msg)
    puts msg unless ENV['QUIET_MODE']
  end

  def debug_no_newline(msg)
    print msg unless ENV['QUIET_MODE']
  end
end 