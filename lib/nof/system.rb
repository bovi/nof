require 'webrick'

# Base class for Controller, Dashboard and RemoteDashboard
# It provides a HTTP interface to the system, a way to register
# routes and provides several default routes.
class System
  PORT = nil
  NORTHBOUND_SYSTEM = nil
  SOUTHBOUND_SYSTEM = nil

  class << self
    # storage for all routes from all subclasses and my own
    def routes
      ancestors.select { |a| a.respond_to?(:own_routes) }
               .map(&:own_routes)
               .reduce({}, &:merge)
    end

    # storage for own routes
    def own_routes
      @routes ||= {}
    end

    # register a new route with a block
    def register(path, &block)
      own_routes[path] = block
    end

    def host
      ENV["#{self.name.upcase}_HOST"] || 'localhost'
    end

    def port
      ENV["#{self.name.upcase}_PORT"] || self::PORT
    end

    def quiet_logging?
      ENV['NOF_VERBOSE'].to_i < 3
    end

    def server_config
      config = { Port: port, Host: host }
      
      if quiet_logging?
        config.merge!(
          Logger: WEBrick::Log.new(File::NULL),
          AccessLog: []
        )
      else
        config.merge!(
          Logger: WEBrick::Log.new($stdout),
          AccessLog: [[
            $stdout,
            "[%{%Y-%m-%d %H:%M:%S}t] #{$system_name} INFO %h %m %U %q -> %s %b",
          ]]
        )
      end
    end
  end

  def setup
    # nothing to do by default
    raise NotImplementedError, "Subclasses must implement the setup method"
  end

  def initialize
    raise "PORT must be set" if self.class.port.nil?
    $system_name = system_name
    $southbound_system_name = self.class.const_get(:SOUTHBOUND_SYSTEM)
    $northbound_system_name = self.class.const_get(:NORTHBOUND_SYSTEM)
    info "Starting on #{self.class.host}:#{self.class.port}"

    begin
      Model.setup_all_tables
    rescue => e
      err "Failed to setup tables: #{e.class}: #{e.message}"
      exit 1
    end

    begin
      @server = WEBrick::HTTPServer.new(self.class.server_config)
    rescue Errno::EADDRINUSE
      err "Port #{self.class.port} is already in use"
      exit 1
    rescue => e
      err "Failed to start: #{e.class}: #{e.message}"
      exit 1
    end

    @activities = Activities.new
    setup_routes
    setup_shutdown_handlers
    setup_sync_handlers
    setup
  end

  def system_name
    case self.class.name
    when 'Controller' then 'CTRL'
    when 'RemoteDashboard' then 'RASH'
    when 'Dashboard' then 'DASH'
    else self.class.name.upcase
    end
  end

  def start
    @server.start
  end
  
  private
  
  def setup_routes
    @server.mount_proc '/' do |req, res|
      handle_request(req, res)
    end
  end
  
  def handle_request(req, res)
    if self.class.routes.key?(req.path)
      self.class.routes[req.path].call(req, res)
    else
      not_found(res)
    end
  end
  
  def not_found(res)
    res.status = 404
    res.body = 'Not Found'
    res.content_type = 'text/plain'
  end

  def setup_sync_handlers
    # Start the sync thread if the system has a northbound system
    if self.class::NORTHBOUND_SYSTEM
      if self.class::SYNC_INTERVAL.nil?
        raise NotImplementedError, "SYNC_INTERVAL must be set for #{self.class.name}"
      else
        @sync_thread = Thread.new do
          loop do
            begin
              sync_with_northbound_system
              sleep self.class::SYNC_INTERVAL
            rescue => e
              err "Sync failed: #{e.message}"
              sleep self.class::SYNC_INTERVAL  # Still wait before retrying
            end
          end
        end
      end
    end
  end

  def sync_with_northbound_system
    northbound_class = Object.const_get(self.class::NORTHBOUND_SYSTEM)
    northbound_host = northbound_class.host
    northbound_port = northbound_class.port

    # Send all new activities to remote dashboard
    uri = URI("http://#{northbound_host}:#{northbound_port}/activities/sync")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.path)
    Activities.northbound_json! do |activities_json|
      request.body = activities_json
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        new_activities = JSON.parse(response.body)['activities']
        sync_num =  Activities.sync(new_activities, sync_source: :northbound)
        info "Synced #{sync_num} activities successfully" unless sync_num.zero?
      else
        err "Sync failed: HTTP Return Code not successful: #{response.code}: #{response.body}"
        raise "Sync failed: HTTP Return Code not successful: #{response.code}: #{response.body}"
      end
    rescue Errno::ECONNREFUSED
      info "#{northbound_class.name} not running for sync"
    rescue => e
      err "Sync failed: #{e.class}: #{e.message}"
    end
  end
  
  def setup_shutdown_handlers
    trap('INT') do
      info "Shutting down"
      @server.shutdown
    end
    trap('TERM') do
      info "Shutting down"
      @server.shutdown
    end
  end

  # common information about the system
  register '/info.json' do |req, res|
    res.body = JSON.generate({
      name: $system_name,
      version: '0.1.0'
    })
    res.content_type = 'application/json'
  end

  # common status information about the system
  # health: ok, ko
  # status: init, synced, oosync
  register '/status.json' do |req, res|
    res.body = JSON.generate({
      health: 'ok',
      status: 'init'
    })
    res.content_type = 'application/json'
  end

  register '/activities.json' do |req, res|
    res.body = Activities.to_json
    res.content_type = 'application/json'
  end

  register '/tasktemplates.json' do |req, res|
    res.body = TaskTemplates.to_json
    res.content_type = 'application/json'
  end
end





