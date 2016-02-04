module RedmineSlack
  module Payload
    class AttachmentFields
      include RedmineSlack::Utils
      
      attr_reader :details

      def initialize(details)
        @details = details
      end

      def fields
        details.map do |detail|
          detail_to_field(detail)
        end
      end

      private

      def detail_to_field(detail)
        if detail.property == "cf"
    			key = CustomField.find(detail.prop_key).name rescue nil
    			title = key
    		elsif detail.property == "attachment"
    			key = "attachment"
    			title = I18n.t :label_attachment
    		else
    			key = detail.prop_key.to_s.sub("_id", "")
    			title = I18n.t "field_#{key}"
    		end

    		short = true
    		value = escape detail.value.to_s

    		case key
    		when "title", "subject", "description"
    			short = false
    		when "tracker"
    			tracker = Tracker.find(detail.value) rescue nil
    			value = escape tracker.to_s
    		when "project"
    			project = Project.find(detail.value) rescue nil
    			value = escape project.to_s
    		when "status"
    			status = IssueStatus.find(detail.value) rescue nil
    			value = escape status.to_s
    		when "priority"
    			priority = IssuePriority.find(detail.value) rescue nil
    			value = escape priority.to_s
    		when "category"
    			category = IssueCategory.find(detail.value) rescue nil
    			value = escape category.to_s
    		when "assigned_to"
    			user = User.find(detail.value) rescue nil
    			value = escape user.to_s
    		when "fixed_version"
    			version = Version.find(detail.value) rescue nil
    			value = escape version.to_s
    		when "attachment"
    			attachment = Attachment.find(detail.prop_key) rescue nil
    			value = "<#{object_url attachment}|#{escape attachment.filename}>" if attachment
    		when "parent"
    			issue = Issue.find(detail.value) rescue nil
    			value = "<#{object_url issue}|#{escape issue}>" if issue
    		end

    		value = "-" if value.empty?

    		result = { :title => title, :value => value }
    		result[:short] = true if short
    		result
      end
    end
  end
end
