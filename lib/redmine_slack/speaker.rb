module RedmineSlack
  class Speaker
    attr_reader :url,
                :msg,
                :icon,
                :channel,
                :username,
                :attachment

    def initialize(opts)
      opts.each do |k, v|
        instance_variable_set "@#{k}", v
      end
    end

    def speak_async
			client = HTTPClient.new
			client.ssl_config.cert_store.set_default_paths
			client.ssl_config.ssl_version = "SSLv23"
			client.post_async url, {:payload => params.to_json}
		rescue
			# Bury exception if connection error
    end

    private

    def params
      {
  			:text => msg,
  			:link_names => 1,
  		}.merge(icon_params).tap do |params|
        params[:channel] = channel if channel.present?
        params[:username] = username if username.present?
        params[:attachments] = [attachment] if attachment.present?
      end
    end

    def icon_params
      {}.tap do |icon_params|
        if icon.present?
    			if icon.start_with? ':'
    				icon_params[:icon_emoji] = icon
    			else
    				icon_params[:icon_url] = icon
    			end
    		end
      end
    end
  end
end
