class IntegrationTest < Minitest::Test
  def setup
    delete_all_db_files

    @controller_pid = spawn('ruby ctrl.rb')
    @dashboard_pid = spawn('ruby dash.rb')
    @rash_pid = spawn('ruby rash.rb')
    @executor_pid = spawn('ruby exec.rb')

    wait_for_startup
  end

  def teardown
    Process.kill('INT', @controller_pid)
    Process.kill('INT', @dashboard_pid)
    Process.kill('INT', @rash_pid)
    Process.kill('INT', @executor_pid)

    Process.wait(@controller_pid)
    Process.wait(@dashboard_pid)
    Process.wait(@rash_pid)
    Process.wait(@executor_pid)

    wait_for_shutdown
  end

  def test_tasktemplate_sync_between_dashboard_and_remotedashboard
    # get initial size of dashboard activities
    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    da = activities.size
    expected_dashboard_activities = da + 1

    response = _get(RemoteDashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    ra = activities.size
    expected_remotedashboard_activities = ra + 1

    # add task to Remote Dashboard
    new_tasktemplate_response = _post(RemoteDashboard,
                                     '/tasktemplate',
                                     {
                                       'type' => 'shell',
                                       'cmd' => 'echo "Hello, World!"',
                                       'pattern' => '(?<greeting>Hello)',
                                       'template' => '{greeting}'
                                     })
    assert_equal '200', new_tasktemplate_response.code, "Task template should be created"
    task_template = JSON.parse(new_tasktemplate_response.body)
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['opts']['cmd']
    assert_equal '(?<greeting>Hello)', task_template['opts']['format']['pattern']
    assert_equal '{greeting}', task_template['opts']['format']['template']
    uuid = task_template['uuid']

    # check if activity exists which created the task template
    response = _get(RemoteDashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_remotedashboard_activities, activities.size,
                 "Activity should be created"
    activity = activities.find { |a| a['action'] == 'tasktemplate_add' && a['opt']['uuid'] == uuid }
    refute_nil activity, "Activity for task template creation should exist"
    assert_equal 'tasktemplate_add', activity['action']
    assert_equal uuid, activity['opt']['uuid']
    assert_equal 'shell', activity['opt']['type'] 
    assert_equal 'echo "Hello, World!"', activity['opt']['opts']['cmd']
    assert_equal '(?<greeting>Hello)', activity['opt']['opts']['format']['pattern']
    assert_equal '{greeting}', activity['opt']['opts']['format']['template']
    assert_equal 'RASH', activity['source_name']

    # check that it is available in the Remote Dashboard
    response = _get(RemoteDashboard, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be accessible"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['opts']['cmd']
    assert_equal '(?<greeting>Hello)', task_template['opts']['format']['pattern']
    assert_equal '{greeting}', task_template['opts']['format']['template']

    # check that it is available in the Dashboard
    wait_for_sync(Dashboard)

    # check if activity was synced
    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_dashboard_activities, activities.size,
                 "Activity should be synced to the Dashboard"
    activity = activities.find { |a| a['action'] == 'tasktemplate_add' && a['opt']['uuid'] == uuid }
    refute_nil activity, "Activity for task template creation should exist"
    assert_equal 'tasktemplate_add', activity['action']
    assert_equal uuid, activity['opt']['uuid']
    assert_equal 'shell', activity['opt']['type'] 
    assert_equal 'echo "Hello, World!"', activity['opt']['opts']['cmd']
    assert_equal '(?<greeting>Hello)', activity['opt']['opts']['format']['pattern']
    assert_equal '{greeting}', activity['opt']['opts']['format']['template']
    assert_equal 'RASH', activity['source_name']

    response = _get(Dashboard, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be synced to the Dashboard"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['opts']['cmd']
    assert_equal '(?<greeting>Hello)', task_template['opts']['format']['pattern']
    assert_equal '{greeting}', task_template['opts']['format']['template']

    response = _get(RemoteDashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_remotedashboard_activities, activities.size,
                 "Activity should still be the same as before"

    # wait for another sync cycle to ensure that duplicate activities are not added
    wait_for_sync(Dashboard)

    response = _get(RemoteDashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_remotedashboard_activities, activities.size,
                 "Activity should still be the same as before even after the second sync"

    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_dashboard_activities, activities.size,
                 "Activity should still be the same as before even after the second sync"
  end

  def test_task_sync_between_controller_and_dashboard
    # get initial size of dashboard activities
    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    da = activities.size
    expected_dashboard_activities = da + 1

    # get initial size of controller activities
    response = _get(Controller, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    ca = activities.size
    expected_controller_activities = ca + 1

    # add tasktemplate to Dashboard
    new_tasktemplate_response = _post(Dashboard,
                                     '/tasktemplate',
                                     {
                                       'type' => 'shell',
                                       'cmd' => 'echo "Hello, World!"',
                                       'pattern' => '(?<greeting>Hello)',
                                       'template' => '{greeting}'
                                     })
    assert_equal '200', new_tasktemplate_response.code, "Task template should be created"
    task_template = JSON.parse(new_tasktemplate_response.body)
    uuid = task_template['uuid']

    # check activity count on dashboard
    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_dashboard_activities, activities.size,
                 "Activity should be created"
    activity = activities.find { |a| a['action'] == 'tasktemplate_add' && a['opt']['uuid'] == uuid }
    refute_nil activity, "Activity for task template creation should exist"
    assert_equal 'DASH', activity['source_name']

    # wait for the controller to sync the activity
    wait_for_sync(Controller)

    # check activity count on controller
    response = _get(Controller, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_controller_activities, activities.size,
                 "Activity should be synced to the Controller"
    activity = activities.find { |a| a['action'] == 'tasktemplate_add' && a['opt']['uuid'] == uuid }
    refute_nil activity, "Activity for task template creation should exist"
    assert_equal 'DASH', activity['source_name'] # activity was created on the Dashboard

    response = _get(Controller, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be synced to the Controller"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['opts']['cmd']
    assert_equal '(?<greeting>Hello)', task_template['opts']['format']['pattern']
    assert_equal '{greeting}', task_template['opts']['format']['template']

    # wait for another sync cycle to ensure that duplicate activities are not added
    wait_for_sync(Controller)

    # check activity count on dashboard
    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_dashboard_activities, activities.size,
                 "Activity should still be the same as before even after the second sync"

    # check activity count on controller
    response = _get(Controller, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_controller_activities, activities.size,
                 "Activity should still be the same as before even after the second sync"
  end

  def test_task_sync_between_controller_and_remotedashboard
    # get initial size of controller activities
    response = _get(Controller, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    ca = activities.size
    expected_controller_activities = ca + 1
    
    # add tasktemplate to Remote Dashboard
    new_tasktemplate_response = _post(RemoteDashboard,
                                     '/tasktemplate',
                                     {
                                       'type' => 'shell',
                                       'cmd' => 'echo "Hello, World!"',
                                       'pattern' => '(?<greeting>Hello)',
                                       'template' => '{greeting}'
                                     })
    assert_equal '200', new_tasktemplate_response.code, "Task template should be created"
    task_template = JSON.parse(new_tasktemplate_response.body)
    uuid = task_template['uuid']
    
    # wait for the sync to the Controller
    wait_for_sync(Dashboard)
    wait_for_sync(Controller)

    # check activity count on controller
    response = _get(Controller, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_controller_activities, activities.size,
                 "Activity should be synced to the Controller"

    # check activity count on Controller
    response = _get(Controller, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_controller_activities, activities.size,
                 "Activity should be synced to the Controller"
    activity = activities.find { |a| a['action'] == 'tasktemplate_add' && a['opt']['uuid'] == uuid }
    refute_nil activity, "Activity for task template creation should exist"
    assert_equal 'RASH', activity['source_name'] # activity was created on the Remote Dashboard

    # check task template on Controller
    response = _get(Controller, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be synced to the Controller"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['opts']['cmd']
    assert_equal '(?<greeting>Hello)', task_template['opts']['format']['pattern']
    assert_equal '{greeting}', task_template['opts']['format']['template']
  end

  def test_host_sync_between_rash_and_dash
    # get initial size of hosts on Dashboard
    response = _get(Dashboard, '/hosts.json')
    assert_equal '200', response.code, "Hosts should be accessible"
    hosts = JSON.parse(response.body)
    sh = hosts.size
    expected_hosts = sh + 1

    # add host to Remote Dashboard
    new_host_response = _post(RemoteDashboard,
                              '/host',
                              {
                                'hostname' => 'test.com',
                                'ip' => '127.0.0.1'
                              })
    assert_equal '200', new_host_response.code, "Host should be created"
    host = JSON.parse(new_host_response.body)
    uuid = host['uuid']

    # wait for the sync to the Dashboard
    wait_for_sync(Dashboard)

    # get hosts from Dashboard and count them
    response = _get(Dashboard, '/hosts.json')
    assert_equal '200', response.code, "Hosts should be accessible"
    hosts = JSON.parse(response.body)
    assert_equal expected_hosts, hosts.size,
                 "Host should be synced to the Dashboard"
    host = hosts.find { |h| h['uuid'] == uuid }
    refute_nil host, "Host should be synced to the Dashboard"
    assert_equal 'test.com', host['hostname']
    assert_equal '127.0.0.1', host['ip']

    # delete host from Remote Dashboard
    delete_host_response = _post(RemoteDashboard,
                                '/host/delete',
                                {
                                  'uuid' => uuid
                                })
    assert_equal '200', delete_host_response.code, "Host should be deleted"

    # wait for the sync to the Dashboard
    wait_for_sync(Dashboard)

    # count hosts on Dashboard
    response = _get(Dashboard, '/hosts.json')
    assert_equal '200', response.code, "Hosts should be accessible"
    hosts = JSON.parse(response.body)
    assert_equal sh, hosts.size,
                 "Host should be deleted"
  end

  def test_task_sync
    # add host to remote dashboard
    new_host_response = _post(RemoteDashboard,
                              '/host',
                              {
                                'hostname' => 'localhost',
                                'ip' => '127.0.0.1'
                              })
    assert_equal '200', new_host_response.code, "Host should be created"
    host = JSON.parse(new_host_response.body)
    host_uuid = host['uuid']

    # add tasktemplate to remote dashboard
    new_tasktemplate_response = _post(RemoteDashboard,
                                      '/tasktemplate',
                                      {
                                        'type' => 'shell',
                                        'cmd' => 'echo "Hello, World!"',
                                        'pattern' => '(?<greeting>Hello)',
                                        'template' => '{greeting}'
                                      })
    assert_equal '200', new_tasktemplate_response.code, "Task template should be created"
    task_template = JSON.parse(new_tasktemplate_response.body)
    tasktemplate_uuid = task_template['uuid']

    # add task to remote dashboard
    new_task_response = _post(RemoteDashboard,
                              '/task',
                              {
                                'host_uuid' => host_uuid,
                                'tasktemplate_uuid' => tasktemplate_uuid
                              })
    assert_equal '200', new_task_response.code, "Task should be created"
    task = JSON.parse(new_task_response.body)
    task_uuid = task['uuid']

    # wait for the sync to the Dashboard
    wait_for_sync(Dashboard)
    wait_for_sync(Controller)
    
    response = _get(Controller, '/jobs.json')
    assert_equal '200', response.code, "Jobs should be accessible"
    jobs = JSON.parse(response.body)
    job = jobs.find { |j| j['uuid'] == task_uuid }
    refute_nil job, "Job should be synced to the Controller"
    assert_equal 'shell', job['type']
    assert_equal 'echo "Hello, World!"', job['opts']['cmd']
    assert_equal '(?<greeting>Hello)', job['opts']['format']['pattern']
    assert_equal '{greeting}', job['opts']['format']['template']
  end
end