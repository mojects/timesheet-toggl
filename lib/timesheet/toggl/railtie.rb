class Timesheet::Toggl::Railtie < Rails::Railtie
  initializer 'Include connector in the controller' do
    config_path = Rails.root + 'config/connectors/toggl.yml'
    if File.exists? config_path
      Timesheet::Toggl.configure YAML.load(config_path)[Rails.env]
    else
      puts 'Run `rails g timesheet-toggl:install`'
    end
  end

  path = File.expand_path '../../generators/timesheet-toggl/install_generator.rb',
    __FILE__
  generators { require path }
end
