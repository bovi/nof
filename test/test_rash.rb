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

  def get_response(path = '')
    _get_response(RemoteDashboard, path)
  end

  def test_index
    response = get_response
    assert_equal '200', response.code, "Remote dashboard index page should be accessible"
  end

  def test_wrong_endpoint
    response = get_response('wrong.json')
    assert_equal '404', response.code, "Remote dashboard wrong endpoint should return 404"
  end

  def test_status
    response = get_response('status.json')
    assert_equal '200', response.code, "Remote dashboard status page should be accessible"
    status = JSON.parse(response.body)
    assert_equal 'ok', status['health'], "Remote dashboard health should be ok"
    assert_equal 'init', status['status'], "Remote dashboard status should be init"
  end

  def test_info
    response = get_response('info.json')
    assert_equal '200', response.code, "Remote dashboard info page should be accessible"
    info = JSON.parse(response.body)
    assert_equal 'RASH', info['name'], "Remote dashboard name should be RASH"
    assert_equal '0.1.0', info['version'], "Remote dashboard version should be 0.1.0"
  end

  def test_activities
    response = get_response('activities.json')
    assert_equal '200', response.code, "Remote dashboard activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal 0, activities.size, "Remote dashboard activities should be empty"
  end
end