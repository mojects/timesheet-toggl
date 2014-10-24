module Timesheet
  module Projects
    PROJECTS_URI = 'https://www.toggl.com/api/v8/projects'

    def create_project(name, workspace_id, client_id)
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
      unless response.response_code == 200
        Rails.logger.error "Project creation failed: #{response.body}"
      end
    end
  end
end
