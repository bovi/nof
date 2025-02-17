class TestResults < Minitest::Test
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

    delete_all_db_files

    sleep 1
  end

  CMD = 'echo "Hello, World!"'
  PATTERN = '(?<greeting>Hello)'
  TEMPLATE = '{ "greeting": "#{greeting}" }'
  INTERVAL = 5

  def test_result_sync
    response = _get(Dashboard, '/results.json')
    assert_equal '200', response.code, "Results should be accessible"
    results = JSON.parse(response.body)
    result_size = results.size

    # add host to dashboard
    new_host_response = _post(Dashboard,
        '/host',
        {
          'hostname' => 'localhost',
          'ip' => '127.0.0.1'
        })
    assert_equal '200', new_host_response.code, "Host should be created"
    host = JSON.parse(new_host_response.body)
    host_uuid = host['uuid']

    # add tasktemplate to dashboard
    new_tasktemplate_response = _post(Dashboard,
                    '/tasktemplate',
                    {
                    'type' => 'shell',
                    'cmd' => CMD,
                    'interval' => INTERVAL,
                    'pattern' => PATTERN,
                    'template' => TEMPLATE
                    })
    assert_equal '200', new_tasktemplate_response.code, "Task template should be created"
    task_template = JSON.parse(new_tasktemplate_response.body)
    tasktemplate_uuid = task_template['uuid']

    # add task to dashboard
    new_task_response = _post(Dashboard,
            '/task',
            {
            'host_uuid' => host_uuid,
            'tasktemplate_uuid' => tasktemplate_uuid
            })
    assert_equal '200', new_task_response.code, "Task should be created"
    task = JSON.parse(new_task_response.body)
    task_uuid = task['uuid']

    # wait for Controller to sync data from Dashboard
    wait_for_sync(Controller)
    # wait for Executor to poll the Controller for jobs
    wait_for_sync(Executor)
    # wait for Executor to push results to Controller
    sleep INTERVAL + 1

    # check the results on the Controller
    response = _get(Controller, '/results.json')
    assert_equal '200', response.code, "Results should be accessible"
    results = JSON.parse(response.body)
    assert results.size > result_size, "There should be more results"
    result = results.last
    assert_equal task_uuid, result['job_uuid'], "Result should be for the correct task"
    assert_equal 'greeting', result['key'], "Result should be correct"
    assert_equal 'Hello', result['value'], "Result should be correct"

    # wait for the Controller to push results to the Dashboard
    wait_for_sync(Controller)

    # check the results
    response = _get(Dashboard, '/results.json')
    assert_equal '200', response.code, "Results should be accessible"
    results = JSON.parse(response.body)
    assert results.size > result_size, "The results should be synced to the Dashboard"
    result = results.last
    assert_equal task_uuid, result['job_uuid'], "Result should be for the correct task"
    assert_equal 'greeting', result['key'], "Result should be correct"
    assert_equal 'Hello', result['value'], "Result should be correct"

    wait_for_sync(Dashboard)

    # check the results on the Remote Dashboard
    response = _get(RemoteDashboard, '/results.json')
    assert_equal '200', response.code, "Results should be accessible"
    results = JSON.parse(response.body)
    assert results.size > result_size, "The results should be synced to the Remote Dashboard"
    result = results.last
    assert_equal task_uuid, result['job_uuid'], "Result should be for the correct task"
  end

  def test_manual_result_sync
    response = _get(Dashboard, '/results.json')
    assert_equal '200', response.code, "Results should be accessible"
    results = JSON.parse(response.body)
    result_size = results.size

    # simulate controller by pushing results to the dashboard directly
    new_results = [
      {
        'id' => rand(1000000),
        'timestamp' => Time.now.to_i,
        'job_uuid' => '550e8400-e29b-41d4-a716-446655440000',
        'key' => 'greeting',
        'value' => 'Hello'
      }
    ]
    response = _post_json(Dashboard, '/results/sync', new_results)
    results = JSON.parse(response.body)
    assert_equal '200', response.code, "Results should be added to the Dashboard: #{results['message']}"
    assert_equal 'ok', results['status'], "Results should be added to the Dashboard #{results['message']}"

    # check results on the Dashboard again
    response = _get(Dashboard, '/results.json')
    assert_equal '200', response.code, "Results should be accessible"
    results = JSON.parse(response.body)
    assert results.size > result_size, "The results should be added to the Dashboard"
    result = results.last
    assert_equal new_results.first['id'], result['id'], "Result should be for the correct task"
    assert_equal new_results.first['job_uuid'], result['job_uuid'], "Result should be for the correct task"
    assert_equal new_results.first['key'], result['key'], "Result should be correct"
    assert_equal new_results.first['value'], result['value'], "Result should be correct"
  end
end