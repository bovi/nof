class DashboardTest < Minitest::Test
  def setup
    # Start the dashboard server with output redirected to /dev/null
    @dash_pid = spawn('ruby dash.rb')
    # Give the server a moment to start
    sleep(2)
  end

  def teardown
    # Shutdown the dashboard server
    Process.kill('INT', @dash_pid)
    Process.wait(@dash_pid)
  end

  def test_index
    response = Net::HTTP.get_response(URI("http://localhost:#{Dashboard.port}"))
    assert_equal '200', response.code, "Dashboard index page should be accessible"
  end

  def test_wrong_endpoint
    response = Net::HTTP.get_response(URI("http://localhost:#{Dashboard.port}/wrong.json"))
    assert_equal '404', response.code, "Dashboard wrong endpoint should return 404"
  end
end