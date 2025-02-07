def _(lvl, msg)
  sys = $system_name
  puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{sys} #{lvl}: #{msg}"
end

def err(message)
  _('ERR', message) if ENV['NOF_VERBOSE'].to_i >= 1
end

def warn(message)
  _('WARN', message) if ENV['NOF_VERBOSE'].to_i >= 2
end

def info(message)
  _('INFO', message) if ENV['NOF_VERBOSE'].to_i >= 3
end

def debug(message)
  _('DEBUG', message) if ENV['NOF_VERBOSE'].to_i >= 4
end
