require 'net/http'
require 'json'
require_relative 'controller'
require_relative 'logging'
require_relative 'executor_shell'

# The Executor is the component that
# executes tasks, collects the results
# and reports them to the Controller.
# The tasks are acquired via a HTTP interface
# from the Controller. The same interface
# is used to report the results.
class Executor
  SYNC_INTERVAL = 5

  def initialize
    $system_name = 'EXEC'
    @running = true
    @task_threads = {}  # uuid => Thread
  end

  def start
    setup_shutdown_handlers
    run_polling_loop
  end

  def self.interval
    ENV['EXECUTOR_INTERVAL']&.to_i || SYNC_INTERVAL
  end

  def running?
    @running
  end

  private

  def run_polling_loop
    while running?
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
    rescue Errno::ECONNREFUSED
      info "Controller not running for polling"
    rescue Errno::ETIMEDOUT, SocketError => e
      warn "Controller timeout for polling: #{e.message}"
    end
  rescue StandardError => e
    err "Error polling controller: #{e.class}: #{e.message}"
  end

  def process_tasks(tasks)
    current_uuids = tasks.map { |t| t['uuid'] }
    
    # Stop and remove tasks that are no longer in the list
    @task_threads.each do |uuid, thread|
      unless current_uuids.include?(uuid)
        info "Stopping task: #{uuid}"
        thread.kill
        @task_threads.delete(uuid)
      end
    end

    # Start new tasks
    tasks.each do |task|
      uuid = task['uuid']
      next if @task_threads[uuid]&.alive?

      runner = task_runner_for(task['type'])
      unless runner
        warn "Unsupported task type: #{task['type']}"
        next
      end

      info "Starting task: #{uuid}"
      @task_threads[uuid] = Thread.new do
        runner.call(task)
      end
    end
  end

  def task_runner_for(type)
    case type
    when 'shell'
      method(:run_shell_task)
    else
      nil
    end
  end

  def setup_shutdown_handlers
    trap('INT') { @running = false }
    trap('TERM') { @running = false }
  end
end 