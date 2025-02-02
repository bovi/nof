require 'minitest/autorun'
require 'net/http'
require 'json'
require 'fileutils'
require 'tmpdir'

ENV['DISABLE_LOGGING'] = '1'

class IntegrationTest < Minitest::Test
  def setup
    # Create separate temp directories for controller and dashboard
    @controller_dir = Dir.mktmpdir
    @dashboard_dir = Dir.mktmpdir
    
    #ENV['CONTROLLER_CONFIG_DIR'] = @controller_dir
    #ENV['DASHBOARD_CONFIG_DIR'] = @dashboard_dir
    
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
    FileUtils.remove_entry @controller_dir
    FileUtils.remove_entry @dashboard_dir
  end

  def test_version_match
    # Get versions from all components
    controller_version = JSON.parse(Net::HTTP.get(URI("http://localhost:1880/version")))['version']
    dashboard_version = JSON.parse(Net::HTTP.get(URI("http://localhost:1080/version")))['version']

    # All components should have the same version
    assert_equal '0.1', controller_version
    assert_equal '0.1', dashboard_version
  end
end 