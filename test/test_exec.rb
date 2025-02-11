class ExecutionTest < Minitest::Test
  def setup
    delete_all_db_files
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
    wait_for_startup
  end

  def teardown
    # Shutdown executor and mock server
    Process.kill('INT', @executor_pid)
    Process.wait(@executor_pid)
    @mock_server.shutdown
    @server_thread.join
    wait_for_shutdown
  end

  def test_polls_controller
    wait_for_sync(Executor)
    assert @request_made, "Executor should poll controller for tasks"
    wait_for_sync(Executor)
    assert @report_made, "Executor should report task result"
    assert_equal 'Hello', @report_data['result']
  end
end
