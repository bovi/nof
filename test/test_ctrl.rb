class ControllerTest < Minitest::Test
  def setup
    delete_all_db_files
    # Start the controller server with output redirected to /dev/null
    @controller_pid = spawn('ruby ctrl.rb')
    # Give the server a moment to start
    wait_for_startup
  end

  def teardown
    # Shutdown the controller server
    Process.kill('INT', @controller_pid)
    Process.wait(@controller_pid)
    wait_for_shutdown
  end

  def get(path = '')
    _get(Controller, path)
  end

  def post(path = '', data = {})
    _post(Controller, path, data)
  end

  def test_index
    response = get
    assert_equal '200', response.code, "Controller index page should be accessible"
  end

  def test_jobs_endpoint
    response = get('jobs.json')
    assert_equal '200', response.code, "Controller jobs endpoint should be accessible"
  end

  def test_wrong_endpoint
    response = get('wrong.json')
    assert_equal '404', response.code, "Controller wrong endpoint should return 404"
  end

  def test_activities
    response = get('activities.json')
    assert_equal '200', response.code, "Controller activities endpoint should return 200"
  end

  def test_status
    response = get('status.json')
    assert_equal '200', response.code, "Controller status page should be accessible"
    status = JSON.parse(response.body)
    assert_equal 'ok', status['health'], "Controller health should be ok"
    assert_equal 'init', status['status'], "Controller status should be init"
  end

  def test_info
    response = get('info.json')
    assert_equal '200', response.code, "Controller info page should be accessible"
    info = JSON.parse(response.body)
    assert_equal 'CTRL', info['name'], "Controller name should be CTRL"
    assert_equal '0.1.0', info['version'], "Controller version should be 0.1.0"
  end

  def test_report
    response = get('results.json')
    assert_equal '200', response.code, "Controller results endpoint should be accessible"
    results = JSON.parse(response.body)
    result_size = results.size

    uuid = "929b366d-dd19-4d03-b5cb-dbed9dcdece6"
    ts = Time.now.to_i
    response = post('report', {'uuid' => uuid, 'result' => {"greeting" => "Hello"}.to_json, 'timestamp' => ts})
    assert_equal '200', response.code, "Controller report endpoint should be accessible"
    report = JSON.parse(response.body)
    assert_equal 'ok', report['status'], "Report should be ok"

    response = get('results.json')
    assert_equal '200', response.code, "Controller results endpoint should be accessible"
    results = JSON.parse(response.body)
    assert_equal result_size + 1, results.size, "Results should have 1 entry"
    assert_equal uuid, results.last['job_uuid'], "Results should have correct job_uuid"
    assert_equal 'greeting', results.last['key'], "Results should have key greeting"
    assert_equal 'Hello', results.last['value'], "Results should have value Hello"
    assert_equal ts, results.last['timestamp'], "Results should have correct timestamp"
  end
end