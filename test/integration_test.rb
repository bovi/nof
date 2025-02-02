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

  SYNC_INTERVAL = 2

  def setup
    # Create test directories
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(CONTROLLER_DIR)
    FileUtils.mkdir_p(DASHBOARD_DIR)
    
    # Set environment variables for configuration directories
    ENV['DISABLE_LOGGING'] = '1'
    ENV['CONTROLLER_CONFIG_DIR'] = CONTROLLER_DIR
    ENV['DASHBOARD_CONFIG_DIR'] = DASHBOARD_DIR
    ENV['CONTROLLER_UPDATE_DATA_INTERVAL'] = SYNC_INTERVAL.to_s
    ENV['CONTROLLER_UPDATE_CONFIG_INTERVAL'] = SYNC_INTERVAL.to_s

    # Start all components
    @dashboard_pid = spawn('ruby', 'dashboard.rb')
    @controller_pid = spawn('ruby', 'controller.rb')
    @executor_pid = spawn('ruby', 'executor.rb')
    
    # Give components time to initialize
    sleep 2
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
    assert_equal 302, response.code.to_i
  end

  def post_dashboard(path, data)
    post(Dashboard, path, data)
  end

  def test_version_match
    # Get versions from all components
    controller_version = get_controller('/version.json')
    dashboard_version = get_dashboard('/version.json')

    # All components should have the same version
    assert_equal Controller::VERSION, controller_version
    assert_equal Dashboard::VERSION, dashboard_version
  end

  def test_host_mgmt
    test_host = 'test-host'
    test_ip = '192.168.1.100'

    # Create a new host via POST request
    post_dashboard('/config/hosts/add', {
      'name' => test_host,
      'ip' => test_ip
    })
    
    # Get the dashboard page and verify the host is listed
    dashboard_response = Net::HTTP.get(URI("http://localhost:#{Dashboard::DEFAULT_PORT}/"))
    assert_includes dashboard_response, test_host
    assert_includes dashboard_response, test_ip

    # wait a moment until the controller syncs the host
    sleep SYNC_INTERVAL + 1

    # Get the controller page and verify the host is listed
    hosts = get_controller('/hosts.json')
    assert_equal 1, hosts.length
    assert_equal test_host, hosts[0]['name']
    assert_equal test_ip, hosts[0]['ip']

    # Delete the host via POST request
    post_dashboard('/config/hosts/delete', {
      'uuid' => hosts[0]['uuid']
    })

    # Get the dashboard page and verify the host is no longer listed
    dashboard_response = Net::HTTP.get(URI("http://localhost:#{Dashboard::DEFAULT_PORT}/"))
    refute_includes dashboard_response, test_host
    refute_includes dashboard_response, test_ip

    # wait a moment until the controller syncs the host
    sleep SYNC_INTERVAL + 1

    # Get the controller page and verify the host is no longer listed
    hosts = get_controller('/hosts.json')
    assert_equal 0, hosts.length
  end
end 