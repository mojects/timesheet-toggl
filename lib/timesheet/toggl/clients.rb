module Timesheet
  module Clients
    CLIENTS_URI = 'https://www.toggl.com/api/v8/clients'

    def create_client(name, workspace_id)
      options = {
        project: {
          name: name,
          wid: workspace_id,
          cid: client_id
        }
      }
      response = Curl.post(PROJECTS_URI, params) do |request|
        request.http_auth_types = :basic
        request.username = config[:api_token]
        request.password = 'api_token'
      end
      if response.response_code == 200
        JSON.parse(response.body, symbolize_names: true)[:data][:id]
      else
        Rails.logger.error "Project creation failed: #{response.body}"
      end
    end
  end
end
