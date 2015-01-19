require_relative 'toggl/version'
require_relative 'toggl/clients'
require_relative 'toggl/projects'
require_relative 'toggl/parser'
require 'curb'
require 'active_support/core_ext/time'
require 'active_support/core_ext/date'
require 'json'
require 'pp'

module Timesheet
  # Export reports from timesheet to toggle.
  # @example
  #   Timesheet::Toggl.new(config).sync_last_month
  #   Timesheet::Toggl.new(config).sync_last_month([14, 88]) # where 14, 88 -- user ids.
  #   Timesheet::Toggl.new(config).sync(from: (Date.today - 1.month), to: Date.today)
  #
  class Toggl
    include Clients
    include Projects

    attr_accessor :config

    BASE_URI = 'https://toggl.com/reports/api/v2/details'

    # Example of config:
    #   api_token: 1971800d4d82861d8f2c1651fea4d212
    #   worspace_id: 123
    #   source_name: 'toggl'
    #   redmine_time_entry_class: 'TimeEntryRedmine' # optional
    #
    def initialize(hash)
      @config = hash
      name = hash[:source_name]
      src = DataSource.create_with(name: name).
        find_or_create_by(config_section_id: name, connector_type: 'toggl')
      @config[:source_id] = src.id
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
    # @return array of time entries' ids
    #
    def synchronize(from, to, user_ids = [])
      params = {
        workspace_id: config[:workspace_id],
        since: from.to_s,
        until: to.to_s,
        user_agent: 'export_to_timesheet'
      }
      params[:user_ids] = user_ids.join(',') unless user_ids.empty?
      first_page = fetch(params, 1)
      te_ids = push(first_page)
      pages = first_page[:total_count] / first_page[:per_page]
      pages.times.map { |page| sync(params, page + 2) }.flatten + te_ids
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
        request.username = config[:api_token]
        request.password = 'api_token'
      end
      parsed = JSON.parse(response.body, symbolize_names: true)
      fail "Request failed: #{parsed} with params #{params}" unless response.response_code == 200
      parsed
    end

    # Push data to timesheet.
    # @param parsed_response [Hash] resulf of fetch
    #
    def push(parsed_response)
      TimeEntry.transaction do
        parsed_response[:data].map { |x| push_record x }
      end
    end

    # Push single record to database.
    # Don't push time entry if no user set.
    #
    def push_record(record)
      params = TogglRecord.new(record, config).push
      record[:id]
    end
  end
end
