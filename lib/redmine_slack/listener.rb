require 'httpclient'

class RedmineSlack::Listener < Redmine::Hook::Listener
	include ERB::Util
	include RedmineSlack::Utils
	include GravatarHelper::PublicMethods

	def controller_issues_new_after_save(context={})
		issue = context[:issue]

		channel = channel_for_project issue.project
		url = url_for_project issue.project

		return unless channel and url
		return if issue.is_private?

		msg = RedmineSlack::Payload::Message.new(
			issue: issue,
			notes: issue.description
		).msg

		gravatar = gravatar_url(issue.author.mail, size: 32)

		attachment = {}
		attachment[:author_name] = escape issue.author
		attachment[:author_icon] = gravatar unless gravatar.nil? || gravatar.empty?
		attachment[:text] = escape issue.description if issue.description
		attachment[:fields] = [{
			:title => I18n.t("field_status"),
			:value => escape(issue.status.to_s),
			:short => true
		}, {
			:title => I18n.t("field_priority"),
			:value => escape(issue.priority.to_s),
			:short => true
		}, {
			:title => I18n.t("field_assigned_to"),
			:value => escape(issue.assigned_to.to_s),
			:short => true
		}]

		attachment[:fields] << {
			:title => I18n.t("field_watcher"),
			:value => escape(issue.watcher_users.join(', ')),
			:short => true
		} if Setting.plugin_redmine_slack[:display_watchers] == 'yes'

		speak msg, channel, attachment, url
	end

	def controller_issues_edit_before_save(context={})
		original = Issue.find(context[:issue][:id])
		context[:params][:original_issue] = original if original
	end

	def controller_issues_edit_after_save(context={})
		issue = context[:issue]
		journal = context[:journal]

		channel = channel_for_project issue.project
		url = url_for_project issue.project
		original_issue = context[:params][:original_issue]

		return unless channel and url and Setting.plugin_redmine_slack[:post_updates] == '1'
		return if issue.is_private?

		# Notify only if some properties updated
		if original_issue
			keys = [:assigned_to_id, :priority_id, :status_id]
			return unless keys.map { |k|
				original_issue[k] == issue[k]
			}.include?(false)
		end

		gravatar = gravatar_url(journal.user.mail, size: 32)

		attachment = {}
		attachment[:author_name] = escape(journal.user.to_s)
		attachment[:author_icon] = gravatar unless gravatar.nil? || gravatar.empty?
		attachment[:text] = escape journal.notes if journal.notes
		attachment[:fields] = journal.details.map { |d| detail_to_field d }

		msg = RedmineSlack::Payload::Message.new(
			issue: issue,
			notes: journal.notes
		).msg

		speak msg, channel, attachment, url
	end

	def controller_agile_boards_update_before_save(context={})
		original = Issue.find(context[:issue][:id])
		context[:params][:original_issue] = original if original
		controller_issues_edit_before_save(context);
	end

	def controller_agile_boards_update_after_save(context={})
		issue = context[:issue]
		journal = issue.journals.last

		channel = channel_for_project issue.project
		url = url_for_project issue.project
		original_issue = context[:params][:original_issue]

		return unless channel and url and Setting.plugin_redmine_slack[:post_updates] == '1'
		return if issue.is_private?

		if original_issue
			keys = [:assigned_to_id, :priority_id, :status_id]
			return unless keys.map { |k|
				original_issue[k] == issue[k]
			}.include?(false)
		end

		msg = RedmineSlack::Payload::Message.new(
			issue: issue,
			notes: journal.notes
		).msg

		gravatar = gravatar_url(journal.user.mail, size: 32)

		attachment = {}
		attachment[:author_name] = escape(journal.user.to_s)
		attachment[:author_icon] = gravatar unless gravatar.nil? || gravatar.empty?
		attachment[:text] = escape journal.notes if journal.notes
		attachment[:fields] = journal.details.map { |d| detail_to_field d }

		speak msg, channel, attachment, url
	end

	def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context={})
		issue = context[:issue]
		journal = issue.current_journal
		changeset = context[:changeset]

		channel = channel_for_project issue.project
		url = url_for_project issue.project

		return unless channel and url and issue.save
		return if issue.is_private?

		msg = RedmineSlack::Payload::Message.new(
			issue: issue
		).msg

		repository = changeset.repository

		revision_url = Rails.application.routes.url_for(
			:controller => 'repositories',
			:action => 'revision',
			:id => repository.project,
			:repository_id => repository.identifier_param,
			:rev => changeset.revision,
			:host => Setting.host_name,
			:protocol => Setting.protocol
		)

		attachment = {}
		attachment[:text] = ll(Setting.default_language, :text_status_changed_by_changeset, "<#{revision_url}|#{escape changeset.comments}>")
		attachment[:fields] = journal.details.map { |d| detail_to_field d }

		speak msg, channel, attachment, url
	end

	def speak(msg, channel, attachment=nil, url=nil)
		url = Setting.plugin_redmine_slack[:slack_url] if not url
		icon = Setting.plugin_redmine_slack[:icon]
		username = Setting.plugin_redmine_slack[:username]

		RedmineSlack::Speaker.new(
			url: url,
			msg: msg,
			icon: icon,
			channel: channel,
			username: username,
			attachment: attachment
		).speak_async
	end

private

	def url_for_project(proj)
		return nil if proj.blank?

		cf = ProjectCustomField.find_by_name("Slack URL")

		return [
			(proj.custom_value_for(cf).value rescue nil),
			(url_for_project proj.parent),
			Setting.plugin_redmine_slack[:slack_url],
		].find{|v| v.present?}
	end

	def channel_for_project(proj)
		return nil if proj.blank?

		cf = ProjectCustomField.find_by_name("Slack Channel")

		val = [
			(proj.custom_value_for(cf).value rescue nil),
			(channel_for_project proj.parent),
			Setting.plugin_redmine_slack[:channel],
		].find{|v| v.present?}

		# Channel name '-' is reserved for NOT notifying
		return nil if val.to_s == '-'
		val
	end

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
