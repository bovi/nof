def log?(lvl)
  logging_level = ENV['NOF_LOGGING']&.to_i || 4
  logging_level < lvl
end

def p(state, msg)
  puts "[#{Time.now}] [#{$system}] #{state}: #{msg}"
end

def debug(message)
  p('DEBUG', message) unless log?(4)
end

def log(message)
  p('LOG', message) unless log?(3)
end

def err(message)
  p('ERROR', message) unless log?(2)
end

def fatal(message)
  p('FATAL', message) unless log?(1)
end