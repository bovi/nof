class IntegrationTest < Minitest::Test
  def setup
    @controller_pid = spawn('ruby ctrl.rb')
    @dashboard_pid = spawn('ruby dash.rb')
    @rash_pid = spawn('ruby rash.rb')
    @executor_pid = spawn('ruby exec.rb')

    sleep 2
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
    assert_equal 'echo "Hello, World!"', task_template['cmd']
    assert_equal '(?<greeting>Hello)', task_template['format']['pattern']
    assert_equal '{greeting}', task_template['format']['template']
    uuid = task_template['uuid']

    # check if activtiies is now higher
    response = _get(RemoteDashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_remotedashboard_activities, activities.size,
                 "Activity should be created"

    # check that it is available in the Remote Dashboard
    response = _get(RemoteDashboard, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be accessible"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['cmd']
    assert_equal '(?<greeting>Hello)', task_template['format']['pattern']
    assert_equal '{greeting}', task_template['format']['template']

    # check that it is available in the Dashboard
    sleep Dashboard::SYNC_INTERVAL + 1 # wait for the sync to the Dashboard

    # check if activity was synced
    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_dashboard_activities, activities.size,
                 "Activity should be synced to the Dashboard"

    response = _get(Dashboard, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be synced to the Dashboard"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['cmd']
    assert_equal '(?<greeting>Hello)', task_template['format']['pattern']
    assert_equal '{greeting}', task_template['format']['template']

    response = _get(RemoteDashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_remotedashboard_activities, activities.size,
                 "Activity should still be the same as before"

    # wait for another sync cycle to ensure that duplicate activities are not added
    sleep Dashboard::SYNC_INTERVAL + 1

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

    # wait for the controller to sync the activity
    sleep Controller::SYNC_INTERVAL + 1

    # check activity count on controller
    response = _get(Controller, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal expected_controller_activities, activities.size,
                 "Activity should be synced to the Controller"

    response = _get(Controller, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be synced to the Controller"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['cmd']
    assert_equal '(?<greeting>Hello)', task_template['format']['pattern']
    assert_equal '{greeting}', task_template['format']['template']

    # wait for another sync cycle to ensure that duplicate activities are not added
    sleep Controller::SYNC_INTERVAL + 1

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
    sleep Dashboard::SYNC_INTERVAL
    sleep Controller::SYNC_INTERVAL + 1

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

    # check task template on Controller
    response = _get(Controller, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be synced to the Controller"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['cmd']
    assert_equal '(?<greeting>Hello)', task_template['format']['pattern']
    assert_equal '{greeting}', task_template['format']['template']
  end
end