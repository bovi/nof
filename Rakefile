require 'rake/testtask'

desc 'Run integration tests (default)'
task :test do
  ENV['QUIET_MODE'] = '1'
  ruby 'test_integration.rb'
end

desc 'Run integration tests with debug output'
task :test_debug do
  ENV['QUIET_MODE'] = nil
  ruby 'test_integration.rb'
end

desc 'Start the system for interactive use'
task :start do
  ruby 'start.rb'
end

desc 'Clean any temporary files'
task :clean do
  # Add any cleanup tasks here if needed
end

# Make test the default task
task default: :test 