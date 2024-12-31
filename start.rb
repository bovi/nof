require 'webrick'
require_relative 'controller'
require_relative 'dashboard'
require_relative 'executor'

controller_port = ENV['CONTROLLER_PORT'] || 1880
dashboard_port = ENV['DASHBOARD_PORT'] || 1080
executor_port = ENV['EXECUTOR_PORT'] || 2080

controller_server = WEBrick::HTTPServer.new(:Port => controller_port)
controller_server.mount '/data', DataController
controller_server.mount '/version', DataController
controller_server.mount '/ping', DataController

dashboard_server = WEBrick::HTTPServer.new(Port: dashboard_port)
dashboard_server.mount '/', DashboardServlet

executor_server = WEBrick::HTTPServer.new(:Port => executor_port)
executor_server.mount '/shell', ExecutorServlet

trap('INT') do
  controller_server.shutdown
  dashboard_server.shutdown
  executor_server.shutdown
end

controller_thread = Thread.new { controller_server.start }
dashboard_thread = Thread.new { dashboard_server.start }
executor_thread = Thread.new { executor_server.start }

controller_thread.join
dashboard_thread.join
executor_thread.join
