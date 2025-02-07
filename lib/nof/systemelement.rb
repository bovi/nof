require 'webrick'

class SystemElement
  PORT = nil

  class << self
    def routes
      @routes ||= {}
    end

    def register(path, &block)
      routes[path] = block
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
          AccessLog: [],
          StartCallback: proc { |server|
            def server.access_log(config, req, res)
              # no-op to suppress access logging
            end
          }
        )
      else
        config.merge!(
          Logger: WEBrick::Log.new($stdout),
          AccessLog: [[
            $stdout,
            "[%{%Y-%m-%d %H:%M:%S}t] #{$system_name} INFO %h %m %U %q -> %s %b",
          ]],
          StartCallback: proc { |server|
            def server.access_log(config, req, res)
              msg = "[#{Time.now}] #{$system_name} INFO #{req.remote_ip} #{req.request_method} #{req.path} ->"
              msg += " #{res.status} #{res.content_length}"
              config[:Logger].info(msg)
            end
          }
        )
      end
    end
  end

  def initialize
    raise "PORT must be set" if self.class.port.nil?
    $system_name = system_name
    info "Starting on #{self.class.host}:#{self.class.port}"
    @server = WEBrick::HTTPServer.new(self.class.server_config)
    setup_routes
    setup_shutdown_handlers
  end

  def system_name
    case self.class.name
    when 'Controller'
      'CTRL'
    when 'RemoteDashboard'
      'RASH'
    when 'Dashboard'
      'DASH'
    else
      self.class.name
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
    trap('INT') { @server.shutdown }
    trap('TERM') { @server.shutdown }
  end
end





