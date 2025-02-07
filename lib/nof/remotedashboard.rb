require_relative 'dashboard'

class RemoteDashboard < Dashboard
  PORT = 8090
  
  register '/' do |res|
    res.body = 'Remote Dashboard Home'
    res.content_type = 'text/plain'
  end
end