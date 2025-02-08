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

# Require all test files in test directory
Dir[File.join(File.dirname(__FILE__), 'test_*.rb')].each { |file| require_relative "../#{file}" }

