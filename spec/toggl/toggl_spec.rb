require_relative '../../lib/timesheet/toggl'

describe Timesheet::Toggl do
  # Flow of data:
  #   initialize with toggl_config
  #   sync for range of time
  #     fetch aka get-request to toggl
  #       => response == first page -- hash with keys :total_count, :per_page, :data
  #     get number of pages
  #     push first page
  #       push each record (from response[:data])
  #         TogglRecord.new(record, config).push
  #         return record[:id]
  #       return array of record ids
  #     return array of record ids
  #     fetch + push other pages
end
