require 'minitest/autorun'
require 'net/http'
require 'open3'
require 'webrick'
require_relative '../lib/nof'

def _get(klass, path = '')
  Net::HTTP.get_response(URI("http://#{klass.host}:#{klass.port}/#{path}".chomp('/')))
end

def _post(klass, path = '', body = {})
  uri = URI("http://#{klass.host}:#{klass.port}/#{path}".chomp('/'))
  req = Net::HTTP::Post.new(uri)
  req.set_form_data(body)
  Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
end

def init_model_db
  Model.setup_all_tables
end

def delete_model_db
  Model.delete_db
end

def wait_for_startup
  sleep 2
end

def wait_for_shutdown
  sleep 2
  system('pkill -f "ruby (ctrl|dash|rash|exec).rb"')
  sleep 1
end

def wait_for_sync(klass)
  # to be sure that syncing is successful, we wait for 2 sync intervals
  sync_interval = klass.const_get(:SYNC_INTERVAL)
  sleep sync_interval + 2
end

def delete_all_db_files
  %w(TEST CTRL DASH RASH).each do |system_name|
    db_file = ENV["NOF_#{system_name.upcase}_DB_FILE"] || ''
    File.delete(db_file) if File.exist?(db_file)
  end
end

$system_name = 'TEST'

temp_dir = Dir.mktmpdir
ENV['NOF_TEST_DB_FILE'] = File.join(temp_dir, 'test.db')
ENV['NOF_CTRL_DB_FILE'] = File.join(temp_dir, 'test_ctrl.db')
ENV['NOF_RASH_DB_FILE'] = File.join(temp_dir, 'test_rash.db')
ENV['NOF_DASH_DB_FILE'] = File.join(temp_dir, 'test_dash.db')
ENV['NOF_TEST_TS_DB_FILE'] = File.join(temp_dir, 'test_ts.db')
ENV['NOF_CTRL_TS_DB_FILE'] = File.join(temp_dir, 'test_ctrl_ts.db')
ENV['NOF_RASH_TS_DB_FILE'] = File.join(temp_dir, 'test_rash_ts.db')
ENV['NOF_DASH_TS_DB_FILE'] = File.join(temp_dir, 'test_dash_ts.db')


# Require all test files in test directory
Dir[File.join(File.dirname(__FILE__), 'test_*.rb')].each do |file|
  if ARGV.empty?
    require_relative "../#{file}"
  elsif ARGV.include?(file.sub('test/test_', '').sub('.rb', ''))
    require_relative "../#{file}"
  end
end

at_exit do
  FileUtils.remove_entry temp_dir if Dir.exist?(temp_dir)
end
