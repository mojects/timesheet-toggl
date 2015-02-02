require 'json'
require 'yaml'
require_relative '../lib/timesheet/toggl'

# We are not going to bring the whole rails here.
# Better to stub needed methods.
class Rails
  def self.logger
    Logger
  end
end
class Logger; def self.error(*params); true; end; end
class Client; end
class TimeEntryRedmine; end
class TimeEntry; end
class DataSourceUser; end

def fixture(name, format = :json, parse = true)
  path = File.expand_path "spec/fixtures/#{name}.#{format}"
  sources = File.read path
  return sources unless parse
  case format
  when :json then JSON.parse(sources, symbolize_names: true)
  when :yaml then YAML.load(sources)
  else sources
  end
end
