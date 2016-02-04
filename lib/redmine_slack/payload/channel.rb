module RedmineSlack
  module Payload
    class Channel
      class << self
        def for_project(project)
          return nil if project.blank?

      		cf = ProjectCustomField.find_by_name("Slack Channel")

      		val = [
      			(project.custom_value_for(cf).value rescue nil),
      			(for_project project.parent),
      			Setting.plugin_redmine_slack[:channel],
      		].find{|v| v.present?}

      		# Channel name '-' is reserved for NOT notifying
      		return nil if val.to_s == '-'
      		val
        end
      end
    end
  end
end
