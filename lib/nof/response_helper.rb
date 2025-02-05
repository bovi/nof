module NOF
  module ResponseHelper
    def json_response(response, data)
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = data.to_json
    end
  end
end 