module Wm3PerfectaBridge
  class Railtie < Rails::Railtie
    rake_tasks do
      Dir[File.join(File.dirname(__FILE__), "tasks/*.rake")].each do |task|
        load task
      end
    end

    initializer "initializer_wm3_perfecta_bridge" do

      # Initializer configuration
      configurations = YAML::load_file(
        "#{Rails.root}/config/#{Wm3PerfectaBridge::CONFIG_FILE_NAME}"
      )[Rails.env]

      if configurations
        Wm3PerfectaBridge::config = configurations.slice(*VALID_CONFIG_KEYS)
      else
        Wm3PerfectaBridge::config = {}
      end

      # Initializer log
      log_file = File.open("#{Rails.root}/log/#{LOG_FILE_NAME}", 'a')
      log_file.sync = true
      Wm3PerfectaBridge::logger = Wm3PerfectaBridgeLogger.new(log_file)
    end
  end
end
