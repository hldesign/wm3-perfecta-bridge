require 'net/ftp'

module Wm3PerfectaBridge
  class FTPSession
    attr_accessor :downloaded_files
    attr_reader :ftp

    private

    def start_session
      Wm3PerfectaBridge::logger.debug("Initializing session")
      @ftp = Net::FTP.new
      @ftp.connect(Wm3PerfectaBridge::config["ftp_host"], Wm3PerfectaBridge::config["ftp_port"])
      log_request("connect")
      @ftp.login(Wm3PerfectaBridge::config["ftp_user"], Wm3PerfectaBridge::config["ftp_password"])
      log_request("login")
    end

    def log_request(action)
      logger_method = @ftp.last_response_code.starts_with?("5") ? :error : :debug
      Wm3PerfectaBridge::logger.send(logger_method, "Performed #{action}, received response with code #{@ftp.last_response_code}:\n#{@ftp.last_response}")
    end

    public

    def initialize
      start_session
      self.downloaded_files = []
    end

    def import_all_files
      # Create folder
      FileUtils::mkdir_p Wm3PerfectaBridge::config["local_output_directory"]
      @ftp.chdir(Wm3PerfectaBridge::config["ftp_input_directory"])

      files = @ftp.nlst('*')

      files.each do |file|
        break if @ftp.closed?
        @ftp.getbinaryfile(file, "#{Wm3PerfectaBridge::config["local_output_directory"]}/#{file}") # Use binary since gettextfile will result in encoding errors
        @downloaded_files << file if @ftp.last_response_code == "226" && !@ftp.closed?
        log_request("getbinaryfile('#{file}')")
      end

    end

    def shutdown
      @ftp.close
      log_request("close")
    end

    def delete_all_downloaded_files
      @downloaded_files.each do |file|
        begin
          File.delete(file)
          Wm3PerfectaBridge::logger.info("Successfully deleted file. (#{file})")
        rescue
          Wm3PerfectaBridge::logger.info("Can not delete file. (#{file})")
        end
      end
    end

  end
end
