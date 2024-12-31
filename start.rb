require 'webrick'
require_relative 'controller'
require_relative 'dashboard'
require_relative 'executor'

d = start_dashboard
c = start_controller

trap('INT') do
  c.shutdown
  d.shutdown
  exit
end

Thread.new { d.start }
sleep 3
Thread.new { c.start }
sleep 3
start_executor

sleep