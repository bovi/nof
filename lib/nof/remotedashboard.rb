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

  def setup
  end

  register '/activities/sync' do |req, res|
    status = 'ko'
    message = ''
    activities = []
    begin
      new_activities = JSON.parse(req.body)
      debug "new_activities: #{new_activities.inspect}"
      synced_num = Activities.sync(new_activities)
      status = 'ok'
      message = "Activities synced successfully: #{synced_num}"
      info "Synced #{synced_num} activities successfully"
      activities = Activities.southbound_raw!
    rescue => e
      err "Sync failed: #{e.message}"
      status = 'error'
      message = e.message
    end
    res.body = {
      'status' => status,
      'message' => message,
      'activities' => activities
    }.to_json
    res.content_type = 'application/json'
    res.status = status == 'ok' ? 200 : 500
  end
end