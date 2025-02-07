class ExecutionTest < Minitest::Test
  def setup
    # Mock the controller server response with silent logging
    @mock_server = WEBrick::HTTPServer.new(
      Port: Controller.port,
      DocumentRoot: '.',
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: [],
      :StartCallback => proc { |server|
        def server.access_log(config, req, res)
          # no-op to suppress access logging
        end
      }
    )
    
    # Add a handler to track if executor makes request
    @request_made = false
    @mock_server.mount_proc '/tasks.json' do |req, res|
      @request_made = true
      res.body = '[{"uuid": "550e8400-e29b-41d4-a716-446655440000"}]'
      res.content_type = 'application/json'
    end

    # Start mock server in background thread
    @server_thread = Thread.new { @mock_server.start }
    
    # Start the executor with output redirected to /dev/null
    @executor_pid = spawn('ruby exec.rb', [:out, :err] => File::NULL)
    sleep(2) # Give time to start up
  end

  def teardown
    # Shutdown executor and mock server
    Process.kill('INT', @executor_pid)
    Process.wait(@executor_pid)
    @mock_server.shutdown
    @server_thread.join
  end

  def test_polls_controller
    sleep(3) # Give executor time to make request
    assert @request_made, "Executor should poll controller for tasks"
  end
end
