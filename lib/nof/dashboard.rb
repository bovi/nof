require_relative 'system'

class Dashboard < System
  PORT = 8080

  register '/' do |res|
    res.body = 'Dashboard Home'
    res.content_type = 'text/plain'
  end
end
