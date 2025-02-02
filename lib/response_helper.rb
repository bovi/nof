module ResponseHelper
  def json_response(response, data, status = 200)
    response.status = status
    response['Content-Type'] = 'application/json'
    response.body = data.to_json
  end
end 