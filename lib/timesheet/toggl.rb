require_relative 'toggl/version'
require_relative 'toggl/railtie' if defined?(Rails)
require 'curb'
require 'active_support/core_ext/time'
require 'active_support/core_ext/date'
require 'json'
require 'pp'

module Timesheet
  # Export reports from timesheet to toggle.
  # @example
  #   Timesheet::Toggl.sync_last_month
  #   Timesheet::Toggl.sync_last_month([14, 88]) # where 14, 88 -- user ids.
  #   Timesheet::Toggl.sync(from: (Date.today - 1.month), to: Date.today)
  #
  module Toggl
    BASE_URI = 'https://toggl.com/reports/api/v2/details'
    PARAMS_MAP = {
      data_source_id: CONFIG[:source_id],
      external_id: :id,
      project: :project,
      comment: :description,
      hours: :dur,
      start_time: :start,
      finish_time: :end
    }

    # Example of config:
    #   api_token: 1971800d4d82861d8f2c1651fea4d212
    #   worspace_id: 123
    #   source_name: 'toggl'
    #
    def configure(hash)
      self.const_set :CONFIG, hash
      name = hash[:source_name]
      src = DataSource.create_with(name: name).
        find_or_create_by(config_section_id: name, connector_type: 'toggl')
      CONFIG[:source_id] = src.id
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

    # Get data from toggl.
    # @param params [Hash] query params for api.
    # @param page [Integer] number of page.
    # @returns [Hash] parsed response from toggl.
    #
    def fetch(params, page)
      print "page #{page}: "
      response = Curl.get(BASE_URI, params.merge(page: page)) do |request|
        request.http_auth_types = :basic
        request.username = CONFIG[:api_token]
        request.password = 'api_token'
      end
      parsed = JSON.load(response.body)
      fail "Request failed: #{parsed}" unless response.response_code == 200
      parsed
    end

    # Push data to timesheet.
    # @param parsed_response [Hash] resulf of fetch
    #
    def push(parsed_response)
      parsed_response['data'].each { |x| push_record x }
    end

    def push_record(record)
      TimeEntry.create_with(params).find_or_create_by(
        external_id: record[:id], data_source_id: CONFIG[:source_id])
    end

    def derive_params(record)
      params = record.reduce({}) do |r, (k, v)|
        next(r) unless PARAMS_MAP[k]
        r.merge(PARAMS_MAP[k] => v)
      end
      params[:spent_on] = record[:start].to_date
      params[:hours] /= 3_600_000.0 # turn milliseconds into hours
      params[:client_id] = Client.find(record[:client]).id
      params[:user_id] = DataSourceUser.find_by(
        data_source_id: CONFIG[:source_id], external_user_id: record[:uid]).
        user_id
    end

    extend self
  end
end
