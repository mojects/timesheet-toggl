require_relative "toggl/version"
require 'curb'
require 'active_support/core_ext/time'
require 'active_support/core_ext/date'
require 'json'
require 'pp'

module Timesheet
  module Toggl
    BASE_URI = 'https://toggl.com/reports/api/v2/details'

    # Example of config:
    #   api_token: 1971800d4d82861d8f2c1651fea4d212
    #   worspace_id: 123
    #   source_name: 'toggl'
    #
    def configure(hash)
      self.const_set :CONFIG, hash
      name = hash[:source_name]
     # src = DataSource.create_with(name: name).
     #   find_or_create_by(config_section_id: name, connector_type: 'toggl')
     # CONFIG[:source_id] = src.id
    end

    def sync_last_month(user_ids = [])
      from = (Date.today << 1).beginning_of_month
      to = Date.today
      synchronize(from, to, user_ids)
    end

    # curl -v -u 1971800d4d82861d8f2c1651fea4d212:api_token
    # -X GET "https://toggl.com/reports/api/v2/details?
    #   workspace_id=123&
    #   since=2013-05-19&
    #   until=2013-05-20&
    #   user_agent=api_test"
    #
    def synchronize(from, to, user_ids = [])
      params = {
        workspace_id: CONFIG[:workspace_id],
        since: from.to_s,
        until: to.to_s,
        user_agent: 'export_to_timesheet',
        user_ids: user_ids.join(',')
      }
      first_page = fetch(params, 1)
      push(first_page)
      pages = first_page['total_count'] / first_page['per_page']
      pages.times { |page| sync(params, page + 2) }
    end

    # Since toggl has per-page api, we will follow them.
    #
    def sync(params, page)
      data = fetch(params, page)
      push(data)
    end

    def fetch(params, page)
      print "page #{page}: "
      response = Curl.get(BASE_URI, params.merge(page: page)) do |request|
        request.http_auth_types = :basic
        request.username = CONFIG[:api_token]
        request.password = 'api_token'
      end
      parsed = JSON.load(response.body)
      raise "Request failed: #{parsed}" unless response.response_code == 200
      parsed
    end

    def push(parsed_response)
      pp parsed_response['data'].map { |x| [x['uid'], x['user']] }
      # TODO: move bunch of queries to timesheet.
      # external_id, comment, user_id, task, project, client_id, hours, start_time, finish_time
    end

    def push_record(record)
      params_map = {
        source_id: CONFIG[:source_id],
        external_id: :id,
        external_project_id: :pid,
        external_project_name: :project,
        external_user_id: :uid,
        external_user_name: :user,
        comment: :description,
        hours: :dur,
        start_time: :start,
        finish_time: :end
      }
      params = record.inject({}) do |r, (k, v)|
        next(r) unless params_map[k]; r.merge(params_map[k] => v)
      end
      TimeEntry.create_with(params).find_or_create_by(
        external_id: record[:id], data_source_id: CONFIG[:source_id])
    end

    extend self
  end
end
