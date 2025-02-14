module Ash
  def setup
    delete_all_db_files
    @ash_pid = spawn("ruby #{_sys_abbrev}.rb")
    wait_for_startup
  end
      
  def teardown
    Process.kill('INT', @ash_pid)
    Process.wait(@ash_pid)
    wait_for_shutdown
  end
      
  def get(path = '')
    _get(_sys_class, path)
  end
      
  def post(path = '', body = {})
    _post(_sys_class, path, body)
  end

  def test_index
    response = get
    assert_equal '200', response.code, "#{_sys_class} index page should be accessible"
  end
      
  def test_wrong_endpoint
    response = get('wrong.json')
    assert_equal '404', response.code, "#{_sys_class} wrong endpoint should return 404"
  end
      
  def test_status
    response = get('status.json')
    assert_equal '200', response.code, "#{_sys_class} status page should be accessible"
    status = JSON.parse(response.body)
    assert_equal 'ok', status['health'], "#{_sys_class} health should be ok"
    assert_equal 'init', status['status'], "#{_sys_class} status should be init"
  end
      
  def test_info
    response = get('info.json')
    assert_equal '200', response.code, "#{_sys_class} info page should be accessible"
    info = JSON.parse(response.body)
    assert_equal _sys_abbrev.to_s.upcase, info['name'], "#{_sys_class} name is wrong"
    assert_equal '0.1.0', info['version'], "#{_sys_class} version should be 0.1.0"
  end
      
  def test_activities
    # get the HTML activities page
    response = get('activities.html')
    assert_equal '200', response.code, "#{_sys_class} activities HTML page should be accessible"

    response = get('activities.json')
    assert_equal '200', response.code, "#{_sys_class} activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_kind_of Integer, activities.size, "#{_sys_class} activities size should be a number"
  end
      
  def test_tasktemplates
    # get the HTML activities page
    response = get('tasktemplates.html')
    assert_equal '200', response.code, "#{_sys_class} task templates HTML page should be accessible"

    response = get('activities.json')
    assert_equal '200', response.code, "#{_sys_class} activities page should be accessible"
    activities = JSON.parse(response.body)
    sa = activities.size
    
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "#{_sys_class} task templates page should be accessible"
    task_templates = JSON.parse(response.body)
    st = task_templates.size
    
    # create a task template
    # by posting to /tasktemplates
    response = post('tasktemplate', { "type" => "shell",
                                      "cmd" => "echo 'Hello, world!'",
                                      "pattern" => "(\w+): (\d+)",
                                      "template" => "{name}: {value}" })
    assert_equal '200', response.code, "#{_sys_class} task template should be created"
    task_template = JSON.parse(response.body)
    assert_equal "shell", task_template['type']
    assert_equal "echo 'Hello, world!'", task_template['opts']['cmd']
    assert_equal "(\w+): (\d+)", task_template['opts']['format']['pattern']
    assert_equal "{name}: {value}", task_template['opts']['format']['template']
      
    # check if the task template was created
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "#{_sys_class} task template should be accessible"
    task_templates = JSON.parse(response.body)
    assert_equal st + 1, task_templates.size, "#{_sys_class} task template should be created"
      
    # check if the activity was created
    response = get('activities.json')
    assert_equal '200', response.code, "#{_sys_class} activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 1, activities.size, "#{_sys_class} activity should be created"
      
    # delete the task template
    response = post('tasktemplate/delete', { "uuid" => task_template['uuid'] })
    assert_equal '200', response.code, "#{_sys_class} task template should be deleted"
      
    # check if the delete activity was created
    response = get('activities.json')
    assert_equal '200', response.code, "#{_sys_class} activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 2, activities.size, "#{_sys_class} activity should be deleted"
      
    # check if the task template was deleted
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "#{_sys_class} task templates page should be accessible"
    task_templates = JSON.parse(response.body)
    assert_equal st, task_templates.size, "#{_sys_class} task template should be deleted"
      
    # check the redirect features
    response = post('tasktemplate', { "type" => "shell",
                                      "cmd" => "echo 'Hello, world!'",
                                      "pattern" => "(\w+): (\d+)",
                                      "template" => "{name}: {value}",
                                      "return_url" => "/tasktemplates.html" })
    assert_equal '302', response.code, "#{_sys_class} redirect should be returned"
    assert_equal "http://#{_sys_class.host}:#{_sys_class.port}/tasktemplates.html", response['Location'],
                 "#{_sys_class} redirect should be to /tasktemplates.html"
      
    # check if the task template was created
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "#{_sys_class} task templates page should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.last
    assert_equal st + 1, task_templates.size, "#{_sys_class} task template should be created"
      
    # check if the activity was created
    response = get('activities.json')
    assert_equal '200', response.code, "#{_sys_class} activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 3, activities.size, "#{_sys_class} activity should be created"
      
    # check if redirect for delete works
    response = post('tasktemplate/delete', { "uuid" => task_template['uuid'],
                                             "return_url" => "/tasktemplates.html" })
    assert_equal '302', response.code, "#{_sys_class} redirect should be returned"
    assert_equal "http://#{_sys_class.host}:#{_sys_class.port}/tasktemplates.html", response['Location'],
                 "#{_sys_class} redirect should be to /tasktemplates.html"
      
    # check if the task template was deleted
    response = get('tasktemplates.json')
    assert_equal '200', response.code, "#{_sys_class} task templates page should be accessible"
    task_templates = JSON.parse(response.body)
    assert_equal st, task_templates.size, "#{_sys_class} task template should be deleted"
      
    # check if the delete activity was created
    response = get('activities.json')
    assert_equal '200', response.code, "#{_sys_class} activities page should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 4, activities.size, "#{_sys_class} activity should be deleted"
  end

  def test_hosts
    # count the hosts before creating any
    response = get('hosts.json')
    assert_equal '200', response.code, "#{_sys_class} hosts page should be accessible"
    hosts = JSON.parse(response.body)
    sh = hosts.size
    sh_expected = sh + 1

    # create a host
    response = post('host', { "hostname" => "test.com", "ip" => "127.0.0.1" })
    assert_equal '200', response.code, "#{_sys_class} host should be created"
    host = JSON.parse(response.body)
    assert_equal "test.com", host['hostname']
    assert_equal "127.0.0.1", host['ip']

    # count the hosts after creating one
    response = get('hosts.json')
    assert_equal '200', response.code, "#{_sys_class} hosts page should be accessible"
    hosts = JSON.parse(response.body)
    assert_equal sh_expected, hosts.size, "#{_sys_class} host should be created"

    # delete the host
    response = post('host/delete', { "uuid" => host['uuid'] })
    assert_equal '200', response.code, "#{_sys_class} host should be deleted"

    # count the hosts after deleting one
    response = get('hosts.json')
    assert_equal '200', response.code, "#{_sys_class} hosts page should be accessible"
    hosts = JSON.parse(response.body)
    assert_equal sh, hosts.size, "#{_sys_class} host should be deleted"
  end

  def test_tasks
    # count the tasks before creating any
    response = get('tasks.json')
    assert_equal '200', response.code, "#{_sys_class} tasks page should be accessible"
    tasks = JSON.parse(response.body)
    st = tasks.size

    # create a task
    response = post('task', { "host_uuid" => "123", "tasktemplate_uuid" => "456" })
    assert_equal '500', response.code, "#{_sys_class} task creation should fail as host and tasktemplate are not existing"
    
    # create a host
    response = post('host', { "hostname" => "test.com", "ip" => "127.0.0.1" })
    assert_equal '200', response.code, "#{_sys_class} host should be created"
    host = JSON.parse(response.body)

    # create a tasktemplate
    response = post('tasktemplate', { "type" => "shell",
                                      "cmd" => "echo 'Hello, world!'",
                                      "pattern" => "(\w+): (\d+)",
                                      "template" => "{name}: {value}" })
    assert_equal '200', response.code, "#{_sys_class} task template should be created"
    tasktemplate = JSON.parse(response.body)

    # create a task
    response = post('task', { "host_uuid" => host['uuid'], "tasktemplate_uuid" => tasktemplate['uuid'] })
    assert_equal '200', response.code, "#{_sys_class} task should be created"
    task = JSON.parse(response.body)
    assert_equal host['uuid'], task['host_uuid']
    assert_equal tasktemplate['uuid'], task['tasktemplate_uuid']

    # count the tasks after creating one
    response = get('tasks.json')
    assert_equal '200', response.code, "#{_sys_class} tasks page should be accessible"
    tasks = JSON.parse(response.body)
    assert_equal st + 1, tasks.size, "#{_sys_class} task should be created"

    # delete the task
    response = post('task/delete', { "uuid" => task['uuid'] })
    assert_equal '200', response.code, "#{_sys_class} task should be deleted"

    # count the tasks after deleting one
    response = get('tasks.json')
    assert_equal '200', response.code, "#{_sys_class} tasks page should be accessible"
    tasks = JSON.parse(response.body)
    assert_equal st, tasks.size, "#{_sys_class} task should be deleted"
  end
end

