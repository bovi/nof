require 'rake/testtask'

desc 'Run integration tests (default)'
task :test do
  ENV['NOF_VERBOSE'] = '2'
  begin
    ruby 'test/test.rb'
  rescue Interrupt
    puts "\nGracefully shutting down..."
  end
end

desc 'Run integration tests with debug output'
task :test_debug do
  ENV['NOF_VERBOSE'] = '4'
  begin
    ruby 'test/test.rb'
  rescue Interrupt
    puts "\nGracefully shutting down..."
  end
end

desc 'Start the system for interactive use'
task :start do
  begin
    ruby 'start.rb'
  rescue Interrupt
    puts "\nShutting down..."
  end
end

desc 'Clean any temporary files'
task :clean do
  # Add any cleanup tasks here if needed
end

# Make test the default task
task default: :test