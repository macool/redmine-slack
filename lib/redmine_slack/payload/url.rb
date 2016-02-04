module RedmineSlack
  module Payload
    class Url
      class << self
        def for_project(project)
          return nil if project.blank?

      		cf = ProjectCustomField.find_by_name("Slack URL")

      		return [
      			(project.custom_value_for(cf).value rescue nil),
      			(for_project project.parent),
      			Setting.plugin_redmine_slack[:slack_url],
      		].find{|v| v.present?}
        end
      end
    end
  end
end
