class RemoteDashboardTest < Minitest::Test
  def setup
    # Start the remote dashboard server with output redirected to /dev/null
    @r_dash_pid = spawn('ruby rash.rb')
    # Give the server a moment to start
    sleep(2)
  end

  def teardown
    # Shutdown the remote dashboard server
    Process.kill('INT', @r_dash_pid)
    Process.wait(@r_dash_pid)
  end

  def test_index
    response = Net::HTTP.get_response(URI("http://localhost:#{RemoteDashboard.port}"))
    assert_equal '200', response.code, "Remote dashboard index page should be accessible"
  end

  def test_wrong_endpoint
    response = Net::HTTP.get_response(URI("http://localhost:#{RemoteDashboard.port}/wrong.json"))
    assert_equal '404', response.code, "Remote dashboard wrong endpoint should return 404"
  end
end