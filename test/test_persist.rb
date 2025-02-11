# test if data persist a restart of a system
class TestPersist < Minitest::Test
  def setup
    delete_all_db_files
    @pids = []
  end

  def teardown
    # this cleanup is only necessary if something went wrong
    @pids.each do |pid|
      begin
        Process.kill("INT", pid)
        Process.wait(pid)
      rescue Errno::ESRCH
        # it seems the process was already correctly killed
      end
    end
    @pids.clear
    wait_for_shutdown
  end

  def _persist_board(klass, system)
    # Start system as a separate process
    system_pid = spawn("ruby #{system}.rb")
    @pids << system_pid
    wait_for_startup

    # Add a task template
    task_template = {
      'type' => 'shell',
      'cmd' => 'echo "test"',
      'pattern' => '(.*)',
      'template' => '\1'
    }

    response = _post(klass, 'tasktemplate', task_template)
    assert_equal '200', response.code, "Task template should be added"
    uuid = JSON.parse(response.body)['uuid']

    # get the activities count
    response = _get(klass, 'activities.json')
    assert_equal '200', response.code, "Activities should be retrieved"
    activities = JSON.parse(response.body)
    activities_count = activities.size

    # Get the current templates
    response = _get(klass, 'tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be retrieved"
    templates = JSON.parse(response.body)
    template = templates.find { |t| t['uuid'] == uuid }
    refute_nil template, "Template should exist"
    assert_equal task_template['type'], template['type'], "Template type should match"
    assert_equal task_template['cmd'], template['cmd'], "Template cmd should match"
    assert_equal task_template['pattern'], template['format']['pattern'], "Template format should match"
    assert_equal task_template['template'], template['format']['template'], "Template format should match"

    # Stop the system process
    Process.kill("INT", system_pid)
    Process.wait(system_pid)
    wait_for_shutdown

    # Start a new system process
    new_system_pid = spawn("ruby #{system}.rb")
    @pids << new_system_pid
    wait_for_startup

    # Get the current templates
    response = _get(klass, 'tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be retrieved"
    templates = JSON.parse(response.body)
    template = templates.find { |t| t['uuid'] == uuid }
    refute_nil template, "Template should exist after restart"
    assert_equal task_template['type'], template['type'], "Template type should match"
    assert_equal task_template['cmd'], template['cmd'], "Template cmd should match"
    assert_equal task_template['pattern'], template['format']['pattern'], "Template format should match"
    assert_equal task_template['template'], template['format']['template'], "Template format should match"

    # get the activities count
    response = _get(klass, 'activities.json')
    assert_equal '200', response.code, "Activities should be retrieved"
    activities = JSON.parse(response.body)
    activities_count_after = activities.size
    assert_equal activities_count, activities_count_after, "Activities count should be the same after restart"

    # Clean up
    Process.kill("INT", new_system_pid)
    Process.wait(new_system_pid)
    wait_for_shutdown
  end

  def test_persist_dashboard
    _persist_board(Dashboard, 'dash')
  end

  def test_persist_remotedashboard
    _persist_board(RemoteDashboard, 'rash')
  end

  def test_persist_controller
    # Start dashboard and controller processes
    dashboard_pid = spawn("ruby dash.rb")
    controller_pid = spawn("ruby ctrl.rb")
    @pids << dashboard_pid
    @pids << controller_pid
    wait_for_startup

    # Add a task template via dashboard
    task_template = {
      'type' => 'shell', 
      'cmd' => 'echo "test"',
      'pattern' => '(.*)',
      'template' => '\1'
    }

    response = _post(Dashboard, 'tasktemplate', task_template)
    assert_equal '200', response.code, "Task template should be added"
    uuid = JSON.parse(response.body)['uuid']

    # Wait for sync to controller
    wait_for_sync(Controller)

    # Verify task exists on controller
    response = _get(Controller, 'tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be retrieved from controller"
    templates = JSON.parse(response.body)
    template = templates.find { |t| t['uuid'] == uuid }
    refute_nil template, "Template should exist on controller"
    assert_equal task_template['type'], template['type'], "Template type should match"
    assert_equal task_template['cmd'], template['cmd'], "Template cmd should match"
    assert_equal task_template['pattern'], template['format']['pattern'], "Template format should match"
    assert_equal task_template['template'], template['format']['template'], "Template format should match"

    # Stop both processes
    Process.kill("INT", dashboard_pid)
    Process.kill("INT", controller_pid)
    Process.wait(dashboard_pid)
    Process.wait(controller_pid)
    wait_for_shutdown

    # restart the controller to check if the task template persists
    new_controller_pid = spawn("ruby ctrl.rb") 
    @pids << new_controller_pid
    wait_for_startup

    # Verify task still exists on controller after restart
    response = _get(Controller, 'tasktemplates.json')
    assert_equal '200', response.code, "Task templates should be retrieved after restart"
    templates = JSON.parse(response.body)
    template = templates.find { |t| t['uuid'] == uuid }
    refute_nil template, "Template should exist on controller after restart"
    assert_equal task_template['type'], template['type'], "Template type should match"
    assert_equal task_template['cmd'], template['cmd'], "Template cmd should match"
    assert_equal task_template['pattern'], template['format']['pattern'], "Template format should match"
    assert_equal task_template['template'], template['format']['template'], "Template format should match"

    # Clean up
    Process.kill("INT", new_controller_pid)
    Process.wait(new_controller_pid)
    wait_for_shutdown
  end
end
