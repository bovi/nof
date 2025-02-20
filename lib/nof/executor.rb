require 'net/http'
require 'json'
require_relative 'controller'
require_relative 'logging'
require_relative 'executor_shell'
require_relative 'executor_oneshot'
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
    @job_threads = {}  # uuid => Thread
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
      poll_and_process_jobs
      sleep self.class.interval
    end
  end

  # acquire job list from the controller
  def poll_and_process_jobs
    begin
      url = "http://#{Controller.host}:#{Controller.port}/jobs.json"
      response = Net::HTTP.get_response(URI(url))
      if response.code == '200'
        jobs = JSON.parse(response.body)
        process_jobs(jobs)
      else
        warn "Error getting jobs: #{response.code}"
      end
    rescue Errno::ECONNREFUSED
      info "Controller not running for polling"
    rescue Errno::ETIMEDOUT, SocketError => e
      warn "Controller timeout for polling: #{e.message}"
    end
  rescue StandardError => e
    err "Error polling controller: #{e.class}: #{e.message}"
  end

  # start and stop jobs based on the jobs list passed
  def process_jobs(jobs)
    current_uuids = jobs.map { |j| j['uuid'] }
    
    # Stop and remove tasks that are no longer in the list
    @job_threads.each do |uuid, thread|
      unless current_uuids.include?(uuid)
        info "Stopping job: #{uuid}"
        thread.kill
        @job_threads.delete(uuid)
      end
    end

    # Start new tasks
    jobs.each do |job|
      uuid = job['uuid']
      next if @job_threads[uuid]&.alive?

      case job['type']
      when 'oneshot'
        info "Oneshot job: #{uuid}"
        run_oneshot_job(job)
      when 'shell'
        info "Starting job: #{uuid}"
        @job_threads[uuid] = Thread.new do
          run_shell_job(job)
        end
      else
        warn "Unsupported job type: #{job['type']}"
        next
      end
    end
  end

  def setup_shutdown_handlers
    trap('INT') { @running = false }
    trap('TERM') { @running = false }
  end
end 