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

  def get_response(path = '')
    _get_response(Dashboard, path)
  end

  def test_index
    response = get_response
    assert_equal '200', response.code, "Dashboard index page should be accessible"
  end

  def test_wrong_endpoint
    response = get_response('wrong.json')
    assert_equal '404', response.code, "Dashboard wrong endpoint should return 404"
  end

  def test_status
    response = get_response('status.json')
    assert_equal '200', response.code, "Dashboard status page should be accessible"
    status = JSON.parse(response.body)
    assert_equal 'ok', status['health'], "Dashboard health should be ok"
    assert_equal 'init', status['status'], "Dashboard status should be init"
  end

  def test_info
    response = get_response('info.json')
    assert_equal '200', response.code, "Dashboard info page should be accessible"
    info = JSON.parse(response.body)
    assert_equal 'DASH', info['name'], "Dashboard name should be DASH"
    assert_equal '0.1.0', info['version'], "Dashboard version should be 0.1.0"
  end

  def test_activities
    response = get_response('activities.json')
    assert_equal '200', response.code, "Dashboard activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal 0, activities.size, "Dashboard activities should be empty"
  end
end