module RedmineSlack
  module Payload
    class Message
      include RedmineSlack::Utils

      attr_reader :issue,
                  :notes

      def initialize(opts)
        opts.each do |k, v|
          instance_variable_set "@#{k}", v
        end
      end

      def msg
        message = "[#{project_str}]"
        message << " <#{issue_url}|#{issue_str}>"
        message << "#{mentions}"
        message
      end

      private

      def issue_url
        Rails.application.routes.url_for(
          issue.event_url(
            host: Setting.host_name,
            protocol: Setting.protocol
          )
        )
      end

      def issue_str
        escape issue
      end

      def project_str
        escape issue.project
      end

      def mentions
    		names = extract_usernames notes
    		names.present? ? "\nTo: " + names.join(', ') : nil
    	end

    	def extract_usernames(text = '')
    		# slack usernames may only contain lowercase letters, numbers,
    		# dashes and underscores and must start with a letter or number.
    		text.scan(/@[a-z0-9][a-z0-9_\-]*/).uniq
    	end
    end
  end
end
