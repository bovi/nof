require_relative 'system'

class Controller < System
  PORT = 8070

  register '/' do |res|
    res.body = 'Controller Index'
    res.content_type = 'text/plain'
  end

  register '/tasks.json' do |res|
    res.body = '[]'
    res.content_type = 'application/json'
  end
end