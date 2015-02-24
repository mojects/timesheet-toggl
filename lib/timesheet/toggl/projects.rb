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
      projects(token, workspace_id).reduce({}) do |a, e|
        cname = clients_hash.detect { |x| x[:id] == e[:cid] }.try(:[], :name)
        pname = e[:name].underscore.gsub(/[^a-zA-z]/, '_')
        a.merge(pname => cname)
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
      JSON.parse(response.body, symbolize_names: true)
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
      JSON.parse(response.body, symbolize_names: true)
    end

    def workspace_projects_url(workspace_id)
      "https://www.toggl.com/api/v8/workspaces/#{workspace_id}/projects"
    end

    def workspace_clients_url(workspace_id)
      "https://www.toggl.com/api/v8/workspaces/#{workspace_id}/clients"
    end
  end
end
