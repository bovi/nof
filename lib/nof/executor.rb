require 'net/http'
require 'json'
require_relative 'controller'
require_relative 'logging'

# The Executor is the component that
# executes tasks, collects the results
# and reports them to the Controller.
# The tasks are acquired via a HTTP interface
# from the Controller. The same interface
# is used to report the results.
class Executor
  def initialize
    $system_name = 'EXEC'
    @running = true
  end

  def start
    setup_shutdown_handlers
    run_polling_loop
  end

  def self.interval
    ENV['EXECUTOR_INTERVAL']&.to_i || 5
  end

  private

  def run_polling_loop
    while @running
      poll_and_process_tasks
      sleep self.class.interval
    end
  end

  def poll_and_process_tasks
    begin
      url = "http://#{Controller.host}:#{Controller.port}/tasks.json"
      response = Net::HTTP.get_response(URI(url))
      
      if response.code == '200'
        tasks = JSON.parse(response.body)
        process_tasks(tasks)
      else
        warn "Error getting tasks: #{response.code}"
      end
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => e
      warn "Could not reach controller: #{e.message}"
    end
  rescue StandardError => e
    err "Error polling controller: #{e.message}"
  end

  def process_tasks(tasks)
    tasks.each do |task|
      info "Processing task: #{task['uuid']}"
    end
  end

  def setup_shutdown_handlers
    trap('INT') { @running = false }
    trap('TERM') { @running = false }
  end
end 