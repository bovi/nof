class ExecutionTest < Minitest::Test
  def setup
    # Mock the controller server response with silent logging
    @mock_server = WEBrick::HTTPServer.new(
      Port: Controller.port,
      DocumentRoot: '.',
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
    
    # Add a handler to track if executor makes request
    @request_made = false
    @report_made = false
    @mock_server.mount_proc '/tasks.json' do |req, res|
      @request_made = true
      data = { 'uuid' => '550e8400-e29b-41d4-a716-446655440000',
               'type' => 'shell',
               'opts' => {
                'interval' => 1,
                'cmd' => 'echo "Hello, World!"',
                'pattern' => '(?<greeting>Hello)',
                'template' => '{greeting}',
               }
             }
      res.body = [data].to_json
      res.content_type = 'application/json'
    end
    @mock_server.mount_proc '/report' do |req, res|
      @report_made = true
      @report_data = JSON.parse(req.body)
      res.body = {'status' => 'ok'}.to_json
      res.content_type = 'application/json'
    end

    # Start mock server in background thread
    @server_thread = Thread.new { @mock_server.start }
    
    # Start the executor with output redirected to /dev/null
    @executor_pid = spawn('ruby exec.rb')
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
    sleep(10) # Give executor time to run and report task
    assert @report_made, "Executor should report task result"
    assert_equal 'Hello', @report_data['result']
  end
end
