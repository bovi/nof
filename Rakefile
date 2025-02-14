require 'rake/testtask'

desc 'Run integration tests (default)'
task :test do
  ENV['NOF_VERBOSE'] = '2'
  begin
    ruby "test/test.rb"
  rescue Interrupt
    puts "\nGracefully shutting down..."
  end
end

desc 'Run integration tests with debug output'
task :test_debug do
  ENV['NOF_VERBOSE'] = '4'
  begin
    ruby "test/test.rb"
  rescue Interrupt
    puts "\nGracefully shutting down..."
  end
end

desc 'Run integration tests with debug output only for test_integration.rb'
task :test_integration_debug do
  ENV['NOF_VERBOSE'] = '4'
  begin
    ruby "test/test.rb test/test_integration.rb"
  rescue Interrupt
    puts "\nGracefully shutting down..."
  end
end

desc 'Run database tests'
task :test_db do
  ENV['NOF_VERBOSE'] = '4'
  begin
    ruby "test/test.rb test/test_db.rb"
  rescue Interrupt
    puts "\nGracefully shutting down..."
  end
end

desc 'Start the system for interactive use'
task :start do
  begin
    ENV['NOF_VERBOSE'] = '4'
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