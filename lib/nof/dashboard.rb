require_relative 'system'

class Dashboard < System
  PORT = 8080

  register '/' do |res|
    res.body = 'Dashboard Home'
    res.content_type = 'text/plain'
  end

  register '/activities.json' do |res|
    res.body = Activities.to_json
    res.content_type = 'application/json'
  end
end
