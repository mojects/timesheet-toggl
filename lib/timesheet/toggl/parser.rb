module Timesheet
  # get issue id
  #   issue-related params
  # get project
  # split by several issues
  #   if one issue, then all good
  #   if several:
  #     delete time entries from timesheet
  #     delete time entries from kibana
  #     add new time entries to timesheet
  # @time_part
  class TogglRecord
    attr_accessor :record, :config

    def initialize(hash, config)
      @descriptions = parse_description hash[:comment]
      @record = hash
      @config = config
    end

    def parse_description(description)
      result = description.scan(/(#\s?\d+[^#]+)/)
      result.empty? ? [description] : result
    end

    def push
      params = descriptions_params
      if params.size > 1
        TimeEntry
          .where(external_id: record[:id], data_source_id: config[:source_id])
          .each { |x| x.delete_from_kibana; x.delete }
        params.each { |x| TimeEntry.create x }
      else
        return unless params[:user_id]
        te = TimeEntry.find_or_create_by(
          external_id: record[:id], data_source_id: config[:source_id])
        te.update params
      end
    end

    def descriptions_params
      params = derive_params
      time_proc = proc { |x| x.scan(/@\s?(\d+)/).flatten.first.to_i }
      times = @descriptions.map(&time_proc).reject(&:zero?)
      one_part = (times.size / descriptions.size.to_f) * params[:hours] / times.sum
      @descriptions.map do |x|
        time = time_proc.call(x)
        hours = time.zero? ?
          (params[:hours] / @descriptions.size) :
          (one_part * time)
        params.merge(comment: x, hours: hours)
      end
    end

    def derive_params
      params = record.reduce({}) do |r, (k, v)|
        next(r) unless params_map[k]
        r.merge(params_map[k] => v)
      end
      params[:data_source_id] = config[:source_id]
      params[:spent_on] = record[:start].to_date
      params[:hours] /= 3_600_000.0 # turn milliseconds into hours
      if iid = issue_id(params)
        params.merge!(issue_related_params(iid))
      end
      params[:client_id] ||= client_id
      params
    end

    def params_map
      {
        id: :external_id,
        project: :project,
        description: :comment,
        dur: :hours,
        start: :start_time,
        end: :finish_time
      }
    end

    def issue_id(params)
      return unless config[:redmine_time_entry_class]
      params[:comment].match(/#\s?(\d+)/).try(:[], 1)
    end

    def issue_related_params(issue_id)
      time_entry_class = Kernel.const_get(config[:redmine_time_entry_class])
      project_id = time_entry_class.issue_class.find(issue_id).project_id
      {
        project: time_entry_class.project(project_id),
        task: time_entry_class.task(issue_id),
        client_id: time_entry_class.client_id(issue_id)
      }
    end

    def client_id
      if client = Client.find_by(name: record[:client])
        client_id = client.id
      else
        Rails.logger.error "No client match to toggl client #{record[:client]}"
      end
      client_id
    end

    def user_id
      data_source_user = DataSourceUser.find_by(
        data_source_id: config[:source_id], external_user_id: record[:uid])
      error = "No user match to toggl user #{record[:user]} (id #{record[:uid]})"
      (Rails.logger.error(error); return) unless data_source_user
      data_source_user.user_id
    end
  end
end
