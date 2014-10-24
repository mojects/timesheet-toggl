module Timesheet
  module Projects
    PROJECTS_URI = 'https://www.toggl.com/api/v8/projects'

    def create_project(name, workspace_id, client_id)
      params = {
        project: {
          name: name,
          wid: workspace_id,
          cid: client_id
        }
      }
      headers = {}
      headers['Content-Type']='application/json'
      headers['X-Requested-With']='XMLHttpRequest'
      headers['Accept']='application/json'
      request = Curl::Easy.new
      request.url = PROJECTS_URI
      request.http_auth_types = :basic
      request.username = config[:api_token]
      request.password = 'api_token'
      response = request.http_post params.to_json
      end
      unless response.response_code == 200
        Rails.logger.error "Project creation failed: #{response.body}"
      end
    end
  end
end
