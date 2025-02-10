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

  def test_add_task_and_check_distribution
    # get initial size of dashboard activities
    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    sa = activities.size

    response = _get(RemoteDashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    ra = activities.size

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
    assert_equal ra + 1, activities.size, "Activity should be created"

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
    debug "waiting for sync with dashboard"
    sleep Dashboard::SYNC_INTERVAL + 1 # wait for the sync to the Dashboard

    # check if activity was synced
    response = _get(Dashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal sa + 1, activities.size, "Activity should be synced to the Dashboard"

    response = _get(Dashboard, '/tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be accessible"
    task_templates = JSON.parse(response.body)
    debug "task_templates: #{task_templates.inspect}"
    debug "uuid: #{uuid}"
    task_template = task_templates.find { |t| t['uuid'] == uuid }
    refute_nil task_template, "Task template should be synced to the Dashboard"
    assert_equal uuid, task_template['uuid']
    assert_equal 'shell', task_template['type']
    assert_equal 'echo "Hello, World!"', task_template['cmd']
    assert_equal '(?<greeting>Hello)', task_template['format']['pattern']
    assert_equal '{greeting}', task_template['format']['template']

    # check if activities on the Remote Dashboard are still the same as before
    response = _get(RemoteDashboard, '/activities.json')
    assert_equal '200', response.code, "Activities should be accessible"
    activities = JSON.parse(response.body)
    assert_equal ra + 1, activities.size, "Activity should be created"
  end
end