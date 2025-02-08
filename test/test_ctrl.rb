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

  def get_response(path = '')
    _get_response(Controller, path)
  end

  def test_index
    response = get_response
    assert_equal '200', response.code, "Controller index page should be accessible"
  end

  def test_tasks_endpoint
    response = get_response('tasks.json')
    assert_equal '200', response.code, "Controller tasks endpoint should be accessible"
  end

  def test_wrong_endpoint
    response = get_response('wrong.json')
    assert_equal '404', response.code, "Controller wrong endpoint should return 404"
  end

  def test_activities
    response = get_response('activities.json')
    assert_equal '404', response.code, "Controller activities endpoint should return 404"
  end

  def test_status
    response = get_response('status.json')
    assert_equal '200', response.code, "Controller status page should be accessible"
    status = JSON.parse(response.body)
    assert_equal 'ok', status['health'], "Controller health should be ok"
    assert_equal 'init', status['status'], "Controller status should be init"
  end

  def test_info
    response = get_response('info.json')
    assert_equal '200', response.code, "Controller info page should be accessible"
    info = JSON.parse(response.body)
    assert_equal 'CTRL', info['name'], "Controller name should be CTRL"
    assert_equal '0.1.0', info['version'], "Controller version should be 0.1.0"
  end
end