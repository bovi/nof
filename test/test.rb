require 'minitest/autorun'
require 'net/http'
require 'open3'
require 'webrick'
require_relative '../lib/nof'

def _get_response(klass, path = '')
  Net::HTTP.get_response(URI("http://#{klass.host}:#{klass.port}/#{path}".chomp('/')))
end

# Require all test files in test directory
Dir[File.join(File.dirname(__FILE__), 'test_*.rb')].each { |file| require_relative "../#{file}" }

