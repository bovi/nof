require 'webrick'

class System
  PORT = nil

  class << self
    def routes
      # Get all routes from parent classes plus our own routes
      ancestors.select { |a| a.respond_to?(:own_routes) }
               .map(&:own_routes)
               .reduce({}, &:merge)
    end

    def own_routes
      @routes ||= {}
    end

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

  def initialize
    raise "PORT must be set" if self.class.port.nil?
    $system_name = system_name
    info "Starting on #{self.class.host}:#{self.class.port}"
    @server = WEBrick::HTTPServer.new(self.class.server_config)
    @activities = Activities.new
    setup_routes
    setup_shutdown_handlers
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
      self.class.routes[req.path].call(res)
    else
      not_found(res)
    end
  end
  
  def not_found(res)
    res.status = 404
    res.body = 'Not Found'
    res.content_type = 'text/plain'
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

  # Register common routes that all systems will have
  register '/info.json' do |res|
    res.body = JSON.generate({
      name: $system_name,
      version: '0.1.0'
    })
    res.content_type = 'application/json'
  end

  register '/status.json' do |res|
    res.body = JSON.generate({
      health: 'ok',
      status: 'init'
    })
    res.content_type = 'application/json'
  end
end





