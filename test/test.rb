require 'minitest/autorun'
require 'net/http'
require 'open3'
require 'webrick'
require_relative '../lib/nof'

# Require all test files in test directory
Dir[File.join(File.dirname(__FILE__), 'test_*.rb')].each { |file| require_relative "../#{file}" }

