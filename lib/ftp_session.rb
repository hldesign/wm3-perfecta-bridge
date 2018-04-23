require 'net/ftp'

module Wm3PerfectaBridge
  class FTPSession
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
    end

    def import_all_files
      @ftp.chdir(Wm3PerfectaBridge::config["ftp_input_directory"])

      files = @ftp.nlst('*')
      downloaded_files = [] # Keep track of successfully downloaded files, in order to delete these later

      files.each do |file|
        break if @ftp.closed?
        @ftp.getbinaryfile(file, "#{Wm3PerfectaBridge::config["local_output_directory"]}/#{file.downcase}") # Use binary since gettextfile will result in encoding errors
        downloaded_files << file if @ftp.last_response_code == "226" && !@ftp.closed?
        log_request("getbinaryfile('#{file}')")
      end

    end
  end
end
