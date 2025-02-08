require_relative 'dashboard'

# The Remote Dashboard is the component
# that is the cloud-based user interface.
# Via it's HTTP interface the user can
# configure the system and view the
# collected data. The same HTTP interface
# is used as an endpoint by the Dashboard
# to syncronize it's activities.
class RemoteDashboard < Dashboard
  PORT = 8090
end