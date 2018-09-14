module Wm3PerfectaBridge
  class Mailer < ActionMailer::Base
    default(
      :from     => 'perfecta-export <no-reply@perfecta.se>',
      :reply_to => 'info@perfecta.se' 
    )

    def send_export(files, type, email)
      datetime = DateTime.now.strftime("%Y%m%d")
      files.each_with_index do |file, index|
        attachments["#{type}-#{datetime}(#{index}).csv"] = {
          content: file,
          mime_type: 'text/csv'
        }
      end

      mail(
        to: email,
        subject: "Perfecta wm3 export",
        body: ''
      )
    end
  end
end
