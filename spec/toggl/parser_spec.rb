require_relative '../spec_helper'

describe Timesheet::TogglRecord do
  let!(:config)       { fixture('config', :yaml) }
  let!(:toggl_record) { fixture('toggl_response')[:data].first }
  let (:record)       { Timesheet::TogglRecord.new toggl_record, config }
  context '#parse_description' do
    it 'return input argument in array if no #<ticket_id> template given' do
      line = 'hello world'
      expect(record.parse_description line).to eq [line]
    end

    it 'return input argument in array if one #<ticket_id> template given' do
      line = '#1488 hello world'
      expect(record.parse_description line).to eq [line]
    end

    it 'return input argument splitted by tickets if 2+ #<ticket_id> templates given' do
      te1 = '#1789 doctor who? '
      te2 = '#1943 are you my mommy?'
      line = te1 + te2
      expect(record.parse_description line).to eq [te1, te2]
    end
  end

  context '#issue_id' do
    it 'don\'t work if no redmine time entry class in config' do
      record = Timesheet::TogglRecord.new({ description: 'hello' }, {})
      params = { comment: '#1382 Alonsee!' }
      expect(record.issue_id params).to be_nil
    end

    context 'with redmine time entry class in config' do
      it 'return nil if no #<issue_id> in comment' do
        params = { comment: '1382 Alonsee!' }
        expect(record.issue_id params).to be_nil
      end

      it 'return id if it is given' do
        params = { comment: '#1382 Alonsee!' }
        expect(record.issue_id params).to eq 1382
      end

      it 'allows space between # and number' do
        params = { comment: '# 1382 Alonsee!' }
        expect(record.issue_id params).to eq 1382
      end
    end
  end

  context '#client_id' do
    it 'Returns id of client with name that exists in database' do
      allow(Client).to receive(:id_by_name).and_return 14
      expect(record.client_id).to eq 14
    end
    it 'Returns nil if no client with given name in database' do
      allow(Client).to receive(:id_by_name).and_return nil
      expect(record.client_id).to be_nil
    end
  end

  context '#common_params' do
    it 'Returns nil if no user in timesheet with given external id' do
      allow(DataSourceUser).to receive(:user_id_for).and_return nil
      expect(record.common_params).to eq nil
    end

    context '#map_params' do
      it 'maps id, project, description, dur, start, end' do
        expect(record.map_params).to eq fixture('params_map_result_1', :yaml)
      end
    end

    it 'Maps common params right' do
      allow(Client).to receive(:id_by_name).and_return 14
      allow(DataSourceUser).to receive(:user_id_for).and_return 4
      expect(record.common_params).to eq fixture('common_params_result_1', :yaml)
    end
  end

  context '#time_parts' do
    it 'sends 0 for descriptions without @<time_parts>' do
      description  = 'hi there man'
      expect(record.time_parts description).to eq 0
    end

    it 'sends <time_parts> for descriptions with @<time_parts' do
      description  = '@3 hi there man'
      expect(record.time_parts description).to eq 3
    end

    it 'allow space between @ and <time_parts>' do
      description  = '@ 3 hi there man'
      expect(record.time_parts description).to eq 3
    end
  end

  context '#descriptions_with_time_parts' do
    it 'use #time_parts for each description' do
      expect(record.descriptions_with_time_parts)
        .to eq({"#1483 @ 2 one; "=>2, "#1231 two; "=>0, "#1332 @1 smooth criminal"=>1})
    end
  end

  context '#descriptions_with_hours' do
    it 'split time between descriptions according to given @<time_parts' do
      expect(record.descriptions_with_hours 4.5)
        .to eq({"#1483 @ 2 one; "=>2, "#1231 two; "=>1.5, "#1332 @1 smooth criminal"=>1})
    end
  end

  context '#issue_related_params' do
    it 'Returns empty hash if no issue id in description' do
      allow(record).to receive(:issue_id).and_return nil
      expect(record.issue_related_params({})).to eq({})
    end

    it 'Returns empty hash if no time entry redmine class' do
      allow(record).to receive(:time_entry_class).and_return nil
      expect(record.issue_related_params({})).to eq({})
    end

    it 'Returns empty hash if no time entry redmine class' do
      allow(record).to receive(:issue_id).and_return 14
      allow(TimeEntryRedmine).to receive(:project_id_for).and_return nil
      expect(record.issue_related_params({})).to eq({})
    end

    it 'derives issue related params from redmine' do
      allow(TimeEntryRedmine).to receive(:project_id_for).and_return 98
      allow(TimeEntryRedmine).to receive(:project_company).and_return 'Tardis Inc'
      allow(TimeEntryRedmine).to receive(:issue_company).and_return 'Tardis Inc'
      allow(TimeEntryRedmine).to receive(:alert?).and_return false
      allow(TimeEntryRedmine).to receive(:project).and_return 'Help Doctor'
      allow(TimeEntryRedmine).to receive(:task).and_return 'Time paradoxes'
      allow(TimeEntryRedmine).to receive(:client_id).and_return 28
      expect(record.issue_related_params({comment: '#134 hey there'}))
        .to eq(project: 'Help Doctor',
               task: 'Time paradoxes',
               client_id: 28,
               project_company: 'Tardis Inc',
               issue_company: 'Tardis Inc',
               alert: false)
    end
  end

  context '#descriptions_params' do
    it 'do nothing if no user_id given' do
      allow(DataSourceUser).to receive(:user_id_for).and_return nil
      expect(record.descriptions_params).to eq nil
    end

    it 'merge common params with description, hours and issue_related_params' do
      allow(DataSourceUser).to receive(:user_id_for).and_return 42
      allow(Client).to receive(:id_by_name).and_return 14
      allow(TimeEntryRedmine).to receive(:project_id_for).with(1332).and_return 13
      allow(TimeEntryRedmine).to receive(:project_id_for).with(1483).and_return 14
      allow(TimeEntryRedmine).to receive(:project_id_for).with(1231).and_return 12
      allow(TimeEntryRedmine).to receive(:project_company).with(12).and_return 'Tardis Inc'
      allow(TimeEntryRedmine).to receive(:project_company).with(13).and_return 'Dalek Inc'
      allow(TimeEntryRedmine).to receive(:project_company).with(14).and_return 'Silence Inc'
      allow(TimeEntryRedmine).to receive(:issue_company).and_return 'Tardis Inc'
      allow(TimeEntryRedmine).to receive(:alert?).and_return false
      allow(TimeEntryRedmine).to receive(:project).and_return 'Help Doctor'
      allow(TimeEntryRedmine).to receive(:task).and_return 'Time paradoxes'
      allow(TimeEntryRedmine).to receive(:client_id).and_return 28
      expect(record.descriptions_params).to eq fixture('descriptions_params_result_1', :yaml)
    end
  end

  context '#push' do
    it 'does nothing if description params are invalid' do
      allow(record).to receive(:descriptions_params).and_return nil
      expect(record.push).to be_nil
    end
    context 'we got one record to insert' do
      it 'does nothing if no user_id for record' do
        allow(record).to receive(:descriptions_params)
          .and_return nil
        expect(record.push).to be_nil
      end
      it 'updates params otherwise' do
        allow(record).to receive(:descriptions_params)
          .and_return [fixture('descriptions_params_result_1', :yaml).first]
        allow(TimeEntry).to receive(:create_or_update)
          .and_return true
        expect(record.push).to eq true
      end
    end

    context 'we got more that one records to insert' do
      it 'does nothing if no user_id for record' do
        allow(DataSourceUser).to receive(:user_id_for).and_return nil
        expect(record.push).to be_nil
      end
      it 'delete records from kibana and timesheet and create new with that params otherwise' do
        allow(record).to receive(:descriptions_params)
          .and_return [fixture('descriptions_params_result_1', :yaml)] * 2
        allow(TimeEntry).to receive(:recreate)
          .and_return true
        expect(record.push).to eq true
      end
    end
  end
end
