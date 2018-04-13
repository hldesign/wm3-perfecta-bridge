require "railtie"
require "wm3-perfecta-bridge-logger.rb"
require "importer.rb"
require "wm3_perfecta_bridge/version"
require "map.rb"
Dir[File.dirname(__FILE__) + '/maps/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/importers/*.rb'].each {|file| require file }

module Wm3PerfectaBridge
    VALID_CONFIG_KEYS = ["store_id", "file_path"]
    CONFIG_FILE_NAME = "wm3-perfecta-bridge.yml"
    LOG_FILE_NAME ="wm3_perfecta_bridge.log"

    mattr_accessor :logger, :config

    def self.import(type, name)
      list = Importer::read_csv(PyramidFilesMap[type])
      updated = []

      logger.info("Importing #{list.count} #{name}")
      list.each { |row| updated << Importer::import(row, name) }
    end
end
