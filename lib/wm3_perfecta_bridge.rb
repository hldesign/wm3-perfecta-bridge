require 'fileutils'

require 'wm3_perfecta_bridge/version'
require 'wm3_perfecta_bridge/wm3-perfecta-bridge-logger.rb'

require 'wm3_perfecta_bridge/importer.rb'
require 'wm3_perfecta_bridge/importers/customer_importer.rb'
require 'wm3_perfecta_bridge/importers/product_importer.rb'
require 'wm3_perfecta_bridge/importers/stock_item_importer.rb'
require 'wm3_perfecta_bridge/importers/product_relation_importer.rb'

require 'wm3_perfecta_bridge/map.rb'
require 'wm3_perfecta_bridge/maps/customer_map.rb'
require 'wm3_perfecta_bridge/maps/product_map.rb'
require 'wm3_perfecta_bridge/maps/pyramid_files_map.rb'

require 'wm3_perfecta_bridge/ftp_session.rb'

require 'wm3_perfecta_bridge/railtie' if defined?(Rails)

module Wm3PerfectaBridge
    VALID_CONFIG_KEYS = [
        "store_id", "file_path", "ftp_host", "ftp_port", "ftp_password",
        "ftp_user", "ftp_input_directory", "ftp_output_directory",
        "local_output_directory"
    ]
    CONFIG_FILE_NAME = "wm3-perfecta-bridge.yml"
    LOG_FILE_NAME ="wm3_perfecta_bridge.log"

    mattr_accessor :logger, :config

    def self.import(type, name)
      logger.info("Importing new files")

      initialize_ftp_session unless Rails.env == "test"

      list = Importer::read_csv(PyramidFilesMap[type])
      if name == "product_relation"
        list = list.map{|s| s["Huvud Artikelnummer"]}.uniq
      end
      updated = []
      failes = []

      logger.info("Importing #{list.count} #{name}")
      list.each do |row|
        begin
          updated << Importer::import(row, name)
        rescue => e
          Wm3PerfectaBridge::logger.error(e.message)
          failes << e.message
          next
        end
      end
      Importer::clear_old_products(list.map{|s| s["Artikelkod"]}.uniq) if name == "product"
      logger.info("Complete importing #{type}s (#{updated.count}/#{list.count})")
      # Delete all downloaded files when finished
      @ftp_session&.delete_all_downloaded_files
    end

    def initialize_ftp_session
      begin
        @ftp_session = FTPSession.new
        @ftp_session.import_all_files
        @ftp_session.shutdown
      rescue => e
        Wm3PerfectaBridge::logger.error("Unable to get files. #{e.message}")
        return
      end
    end

end
