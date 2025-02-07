require_relative 'systemelement'

class Dashboard < SystemElement
  PORT = 8080

  register '/' do |res|
    res.body = 'Dashboard Home'
    res.content_type = 'text/plain'
  end
end
