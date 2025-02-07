class ControllerTest < Minitest::Test
  def setup
    # Start the controller server with output redirected to /dev/null
    @controller_pid = spawn('ruby ctrl.rb')
    # Give the server a moment to start
    sleep(2)
  end

  def teardown
    # Shutdown the controller server
    Process.kill('INT', @controller_pid)
    Process.wait(@controller_pid)
  end

  def test_index
    response = Net::HTTP.get_response(URI("http://localhost:#{Controller.port}"))
    assert_equal '200', response.code, "Controller index page should be accessible"
  end

  def test_tasks_endpoint
    response = Net::HTTP.get_response(URI("http://localhost:#{Controller.port}/tasks.json"))
    assert_equal '200', response.code, "Controller tasks endpoint should be accessible"
  end

  def test_wrong_endpoint
    response = Net::HTTP.get_response(URI("http://localhost:#{Controller.port}/wrong.json"))
    assert_equal '404', response.code, "Controller wrong endpoint should return 404"
  end
end