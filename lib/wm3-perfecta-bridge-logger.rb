class Wm3PerfectaBridgeLogger < Logger
  def format_message(severity, datetime, progname, msg)
    "[#{severity}][#{datetime}]: #{msg}\n"
  end
end

