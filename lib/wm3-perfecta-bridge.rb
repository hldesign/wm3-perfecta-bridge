require "railtie"
require "wm3-perfecta-bridge-logger.rb"
require "importer.rb"
require "wm3_perfecta_bridge/version"
require "map.rb"
require "ftp_session.rb"

Dir[File.dirname(__FILE__) + '/maps/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/importers/*.rb'].each {|file| require file }

module Wm3PerfectaBridge
    VALID_CONFIG_KEYS = [
        "store_id", "file_path", "ftp_host", "ftp_port", "ftp_password",
        "ftp_user", "ftp_input_directory", "ftp_output_directory"]
    CONFIG_FILE_NAME = "wm3-perfecta-bridge.yml"
    LOG_FILE_NAME ="wm3_perfecta_bridge.log"

    mattr_accessor :logger, :config

    def self.import(type, name)
      logger.info("Importing new files")

      begin
        ftp_session = FTPSession.new
        ftp_session.import_all_files
        ftp_session.shutdown
      rescue => e
        Wm3PerfectaBridge::logger.error("Unable to get files. #{e.message}")
        return
      end

      list = Importer::read_csv(PyramidFilesMap[type])
      updated = []

      logger.info("Importing #{list.count} #{name}")
      list.each { |row| updated << Importer::import(row, name) }
    end
end
