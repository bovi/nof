require 'minitest/autorun'
require 'net/http'
require 'json'
require 'fileutils'
require 'tmpdir'

require_relative '../lib/nof'

class IntegrationTest < Minitest::Test
  TEST_DIR = File.expand_path('../tmp/test', __dir__)
  CONTROLLER_DIR = File.join(TEST_DIR, 'controller')
  DASHBOARD_DIR = File.join(TEST_DIR, 'dashboard')
  
  TEST_HOST = 'test-host'
  TEST_IP = '192.168.1.100'
  TEST_GROUP = 'test-group'
  TEST_COMMAND = 'echo "test"'
  TEST_SCHEDULE = '5'
  TEST_TYPE = 'shell'

  SYNC_INTERVAL = 2

  def setup
    # Create test directories
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(CONTROLLER_DIR)
    FileUtils.mkdir_p(DASHBOARD_DIR)
    
    # Set environment variables for configuration directories
    ENV['NOF_LOGGING'] = '0'
    ENV['CONTROLLER_CONFIG_DIR'] = CONTROLLER_DIR
    ENV['DASHBOARD_CONFIG_DIR'] = DASHBOARD_DIR
    ENV['CONTROLLER_UPDATE_DATA_INTERVAL'] = SYNC_INTERVAL.to_s
    ENV['CONTROLLER_UPDATE_CONFIG_INTERVAL'] = SYNC_INTERVAL.to_s

    # Start all components
    @dashboard_pid = spawn('ruby', 'dashboard.rb')
    sleep 1
    @controller_pid = spawn('ruby', 'controller.rb')
    sleep 1
    @executor_pid = spawn('ruby', 'executor.rb')
    sleep 1
  end

  def teardown
    # Kill all components
    Process.kill('INT', @dashboard_pid)
    Process.kill('INT', @controller_pid)
    Process.kill('INT', @executor_pid)

    sleep 5
    
    # Clean up test directories
    FileUtils.rm_rf(TEST_DIR)
  end

  def get(service, path)
    uri = URI("http://localhost:#{service::DEFAULT_PORT}#{path}")
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end

  def get_dashboard(path)
    get(Dashboard, path)
  end

  def get_controller(path)
    get(Controller, path)
  end

  def post(service, path, data)
    uri = URI("http://localhost:#{service::DEFAULT_PORT}#{path}")
    response = Net::HTTP.post(uri, URI.encode_www_form(data))
    if response.code.to_i == 500
      puts "Server error: #{response.body}"
    end
  end

  def post_dashboard(path, data)
    post(Dashboard, path, data)
  end

  def _test_version_match
    # Get versions from all components
    controller_version = get_controller('/version.json')
    dashboard_version = get_dashboard('/version.json')

    # All components should have the same version
    assert_equal Controller::VERSION, controller_version
    assert_equal Dashboard::VERSION, dashboard_version
  end

  def test_ux
    # check if controller has the same data
    controller_groups = get_controller('/groups.json')
    assert_equal 0, controller_groups.length
    controller_hosts = get_controller('/hosts.json')
    assert_equal 0, controller_hosts.length
    controller_tasks = get_controller('/tasks.json')
    assert_equal 0, controller_tasks.length

    # INITIAL STATE
    groups = get_dashboard('/groups.json')
    assert_equal 0, groups.length
    hosts = get_dashboard('/hosts.json')
    assert_equal 0, hosts.length
    task_templates = get_dashboard('/task_templates.json')
    assert_equal 0, task_templates.length

    # CREATE GROUP
    post_dashboard('/config/groups/add', {
      'name' => TEST_GROUP
    })
    groups = get_dashboard('/groups.json')
    assert_equal 1, groups.length
    assert_equal TEST_GROUP, groups[0]['name']

    # CREATE HOST
    post_dashboard('/config/hosts/add', {
      'name' => TEST_HOST,
      'group_uuids' => [groups[0]['uuid']],
      'ip' => TEST_IP
    })
    hosts = get_dashboard('/hosts.json')
    assert_equal 1, hosts.length
    assert_equal TEST_HOST, hosts[0]['name']
    assert_equal TEST_IP, hosts[0]['ip']
    assert_equal [groups[0]['uuid']], hosts[0]['group_uuids']

    # CREATE TASK TEMPLATE
    post_dashboard('/config/task_templates/add', {
      'command' => TEST_COMMAND,
      'schedule' => TEST_SCHEDULE,
      'type' => TEST_TYPE,
      'group_uuids' => [groups[0]['uuid']]
    })
    task_templates = get_dashboard('/task_templates.json')
    assert_equal 1, task_templates.length
    assert_equal TEST_COMMAND, task_templates[0]['command']
    assert_equal TEST_SCHEDULE.to_i, task_templates[0]['schedule']
    assert_equal TEST_TYPE, task_templates[0]['type']
    assert_equal [groups[0]['uuid']], task_templates[0]['group_uuids']

    # now check dashboard index
    uri = URI("http://localhost:#{Dashboard::DEFAULT_PORT}/")
    dashboard_index = Net::HTTP.get(uri)
    assert_includes dashboard_index, TEST_COMMAND
    assert_includes dashboard_index, TEST_GROUP
    assert_includes dashboard_index, TEST_HOST
    assert_includes dashboard_index, TEST_IP
    assert_includes dashboard_index, TEST_TYPE

    # wait for sync
    sleep SYNC_INTERVAL + 1

    # check if controller has the same data
    controller_groups = get_controller('/groups.json')
    assert_equal 1, controller_groups.length
    assert_equal TEST_GROUP, controller_groups[0]['name']

    controller_hosts = get_controller('/hosts.json')
    assert_equal 1, controller_hosts.length
    assert_equal TEST_HOST, controller_hosts[0]['name']
    assert_equal TEST_IP, controller_hosts[0]['ip']
    assert_equal [groups[0]['uuid']], controller_hosts[0]['group_uuids'] 

    controller_tasks = get_controller('/tasks.json')
    assert_equal 1, controller_tasks.length
    assert_equal TEST_COMMAND, controller_tasks[0]['command']
    assert_equal TEST_SCHEDULE.to_i, controller_tasks[0]['schedule']
    assert_equal TEST_TYPE, controller_tasks[0]['type']

    # DELETE TASK TEMPLATE
    post_dashboard('/config/task_templates/delete', {
      'uuid' => task_templates[0]['uuid']
    })
    task_templates = get_dashboard('/task_templates.json')
    assert_equal 0, task_templates.length

    # DELETE HOST
    post_dashboard('/config/hosts/delete', {
      'uuid' => hosts[0]['uuid']
    })
    hosts = get_dashboard('/hosts.json')
    assert_equal 0, hosts.length

    # DELETE GROUP
    post_dashboard('/config/groups/delete', {
      'uuid' => groups[0]['uuid']
    })
    assert_equal 0, get_dashboard('/groups.json').length

    # now check dashboard index if the items are gone
    uri = URI("http://localhost:#{Dashboard::DEFAULT_PORT}/")
    dashboard_index = Net::HTTP.get(uri)
    refute_includes dashboard_index, TEST_COMMAND
    refute_includes dashboard_index, TEST_GROUP
    refute_includes dashboard_index, TEST_HOST
    refute_includes dashboard_index, TEST_IP
    refute_includes dashboard_index, TEST_TYPE

    # wait for sync
    sleep SYNC_INTERVAL + 1

    # check if controller has the same data
    controller_groups = get_controller('/groups.json')
    assert_equal 0, controller_groups.length
    controller_hosts = get_controller('/hosts.json')
    assert_equal 0, controller_hosts.length
    controller_tasks = get_controller('/tasks.json')
    assert_equal 0, controller_tasks.length
  end

  def test_ux_delete_group
    # CREATE GROUP
    post_dashboard('/config/groups/add', {
      'name' => TEST_GROUP
    })
    groups = get_dashboard('/groups.json')

    # CREATE HOST
    post_dashboard('/config/hosts/add', {
      'name' => TEST_HOST,
      'group_uuids' => [groups[0]['uuid']],
      'ip' => TEST_IP
    })

    # CREATE TASK TEMPLATE
    post_dashboard('/config/task_templates/add', {
      'command' => TEST_COMMAND,
      'schedule' => TEST_SCHEDULE,
      'type' => TEST_TYPE,
      'group_uuids' => [groups[0]['uuid']]
    })

    groups = get_dashboard('/groups.json')
    assert_equal 1, groups.length
    hosts = get_dashboard('/hosts.json')
    assert_equal 1, hosts.length
    task_templates = get_dashboard('/task_templates.json')
    assert_equal 1, task_templates.length

    # DELETE GROUP
    post_dashboard('/config/groups/delete', {
      'uuid' => groups[0]['uuid']
    })
    groups = get_dashboard('/groups.json')
    assert_equal 0, groups.length
    hosts = get_dashboard('/hosts.json')
    assert_equal 1, hosts.length
    task_templates = get_dashboard('/task_templates.json')
    assert_equal 1, task_templates.length

    # DELETE HOST
    post_dashboard('/config/hosts/delete', {
      'uuid' => hosts[0]['uuid']
    })
    hosts = get_dashboard('/hosts.json')
    assert_equal 0, hosts.length

    # DELETE TASK TEMPLATE
    post_dashboard('/config/task_templates/delete', {
      'uuid' => task_templates[0]['uuid']
    })
    task_templates = get_dashboard('/task_templates.json')
    assert_equal 0, task_templates.length
  end
end 
