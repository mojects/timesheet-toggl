module TimeEntryConnector::Generators
  class InstallGenerator < ::Rails::Generators::Base
    desc 'Generates a custom config in config/connectors/toggl.yml'

    def source_paths
      [File.expand_path("../templates", __FILE__)]
    end

    def copy_config
      template 'config.yml', 'config/connectors/toggl.yml'
    end
  end
end
