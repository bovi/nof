fork do
  exec 'ruby', 'dashboard.rb'
end

fork do
  exec 'ruby', 'controller.rb'
end

fork do
  exec 'ruby', 'executor.rb'
end

sleep