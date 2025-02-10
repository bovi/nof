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

  def get(path = '')
    _get(Dashboard, path)
  end

  def post(path = '', body = {})
    _post(Dashboard, path, body)
  end

  def test_index
    response = get
    assert_equal '200', response.code, "Dashboard index page should be accessible"
  end

  def test_wrong_endpoint
    response = get('wrong.json')
    assert_equal '404', response.code, "Dashboard wrong endpoint should return 404"
  end

  def test_status
    response = get('status.json')
    assert_equal '200', response.code, "Dashboard status page should be accessible"
    status = JSON.parse(response.body)
    assert_equal 'ok', status['health'], "Dashboard health should be ok"
    assert_equal 'init', status['status'], "Dashboard status should be init"
  end

  def test_info
    response = get('info.json')
    assert_equal '200', response.code, "Dashboard info page should be accessible"
    info = JSON.parse(response.body)
    assert_equal 'DASH', info['name'], "Dashboard name should be DASH"
    assert_equal '0.1.0', info['version'], "Dashboard version should be 0.1.0"
  end

  def test_activities
    response = get('activities.json')
    assert_equal '200', response.code, "Dashboard activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal 0, activities.size, "Dashboard activities should be empty"
  end

  def test_tasktemplates
    response = get('activities.json')
    assert_equal '200', response.code, "Activities page should be accessible"
    activities = JSON.parse(response.body)
    sa = activities.size

    response = get('tasktemplates.json')
    assert_equal '200', response.code, "Task templates page should be accessible"
    task_templates = JSON.parse(response.body)
    st = task_templates.size

    # create a task template
    # by posting to /tasktemplates
    response = post('tasktemplate', { "type" => "shell",
                                      "cmd" => "echo 'Hello, world!'",
                                      "pattern" => "(\w+): (\d+)",
                                      "template" => "{name}: {value}" })
    assert_equal '200', response.code, "Task template should be created"
    task_template = JSON.parse(response.body)
    assert_equal "shell", task_template['type']
    assert_equal "echo 'Hello, world!'", task_template['cmd']
    assert_equal "(\w+): (\d+)", task_template['format']['pattern']
    assert_equal "{name}: {value}", task_template['format']['template']

    # check if the task template was created
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "Task template should be accessible"
    task_templates = JSON.parse(response.body)
    assert_equal st + 1, task_templates.size, "Task template should be created"

    # check if the activity was created
    response = get('activities.json')
    assert_equal '200', response.code, "Activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 1, activities.size, "Activity should be created"

    # delete the task template
    response = post('tasktemplate/delete', { "uuid" => task_template['uuid'] })
    assert_equal '200', response.code, "Task template should be deleted"

    # check if the delete activity was created
    response = get('activities.json')
    assert_equal '200', response.code, "Activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 2, activities.size, "Activity should be deleted"

    # check if the task template was deleted
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "Task templates page should be accessible"
    task_templates = JSON.parse(response.body)
    assert_equal st, task_templates.size, "Task template should be deleted"

    # check the redirect features
    response = post('tasktemplate', { "type" => "shell",
                                      "cmd" => "echo 'Hello, world!'",
                                      "pattern" => "(\w+): (\d+)",
                                      "template" => "{name}: {value}",
                                      "return_url" => "/tasktemplates.html" })
    assert_equal '302', response.code, "Redirect should be returned"
    assert_equal "http://#{Dashboard.host}:#{Dashboard.port}/tasktemplates.html", response['Location'], "Redirect should be to /tasktemplates.html"

    # check if the task template was created
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "Task templates page should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.last
    assert_equal st + 1, task_templates.size, "Task template should be created"

    # check if the activity was created
    response = get('activities.json')
    assert_equal '200', response.code, "Activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 3, activities.size, "Activity should be created"
    
    # check if redirect for delete works
    response = post('tasktemplate/delete', { "uuid" => task_template['uuid'],
                                             "return_url" => "/tasktemplates.html" })
    assert_equal '302', response.code, "Redirect should be returned"
    assert_equal "http://#{Dashboard.host}:#{Dashboard.port}/tasktemplates.html", response['Location'], "Redirect should be to /tasktemplates.html"
    
    # check if the task template was deleted
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "Task templates page should be accessible"
    task_templates = JSON.parse(response.body)
    assert_equal st, task_templates.size, "Task template should be deleted"

    # check if the delete activity was created
    response = get('activities.json')
    assert_equal '200', response.code, "Activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 4, activities.size, "Activity should be deleted"
  end
end