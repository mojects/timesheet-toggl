module Timesheet
  # Module for projects creating/reading from toggl via api.
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
      headers['Content-Type']     = 'application/json'
      headers['X-Requested-With'] = 'XMLHttpRequest'
      headers['Accept']           = 'application/json'
      response = Curl::Easy.http_post(PROJECTS_URI, params.to_json) do |request|
        request.http_auth_types = :basic
        request.username = config[:api_token]
        request.password = 'api_token'
        request.headers = headers
      end
      return if response.response_code == 200
      Rails.logger.error "Project creation failed: #{response.body}"
    end

    def projects_with_clients(token, workspace_id)
      clients_hash = clients(token, workspace_id)
      projects(token, workspace_id).map do |p|
        cname = clients_hash.detect { |x| x[:id] == p[:cid] }.try(:[], :name)
        pname = p[:name].underscore.gsub(/[^a-zA-z]/, '_')
        { client: cname, project: pname, project_origin: p[:name] }
      end
    end

    # Get projects from toggl
    # @returns [Array[Hash]] of projects, parsed json response
    #
    def projects(token, workspace_id)
      response = Curl.get(workspace_projects_url(workspace_id)) do |request|
        request.http_auth_types = :basic
        request.username = token
        request.password = 'api_token'
      end
      parse_body(response.body) || []
    end

    # Get clients from toggl
    # @returns [Array[Hash]] of projects, parsed json response
    #
    def clients(token, workspace_id)
      response = Curl.get(workspace_clients_url(workspace_id)) do |request|
        request.http_auth_types = :basic
        request.username = token
        request.password = 'api_token'
      end
      parse_body(response.body) || []
    end

    def workspace_projects_url(workspace_id)
      "https://www.toggl.com/api/v8/workspaces/#{workspace_id}/projects"
    end

    def workspace_clients_url(workspace_id)
      "https://www.toggl.com/api/v8/workspaces/#{workspace_id}/clients"
    end

    def parse_body(body)
      JSON.parse(body, symbolize_names: true, quirks_mode: true)
    end
  end
end
