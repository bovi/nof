require 'minitest/autorun'
require 'net/http'
require 'json'
require 'fileutils'
require 'tmpdir'

require_relative '../lib'


class IntegrationTest < Minitest::Test
  TEST_DIR = File.expand_path('../tmp/test', __dir__)
  CONTROLLER_DIR = File.join(TEST_DIR, 'controller')
  DASHBOARD_DIR = File.join(TEST_DIR, 'dashboard')

  def setup
    # Create test directories
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(CONTROLLER_DIR)
    FileUtils.mkdir_p(DASHBOARD_DIR)
    
    # Set environment variables for configuration directories
    ENV['DISABLE_LOGGING'] = '1'
    ENV['CONTROLLER_CONFIG_DIR'] = CONTROLLER_DIR
    ENV['DASHBOARD_CONFIG_DIR'] = DASHBOARD_DIR
    
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

    sleep 2
    
    # Clean up test directories
    FileUtils.rm_rf(TEST_DIR)
  end

  def test_version_match
    # Get versions from all components
    controller_version = JSON.parse(Net::HTTP.get(URI("http://localhost:#{Controller::DEFAULT_PORT}/version")))['version']
    dashboard_version = JSON.parse(Net::HTTP.get(URI("http://localhost:#{Dashboard::DEFAULT_PORT}/version")))['version']

    # All components should have the same version
    assert_equal Controller::VERSION, controller_version
    assert_equal Dashboard::VERSION, dashboard_version
  end
end 