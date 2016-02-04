require 'httpclient'

class RedmineSlack::Listener < Redmine::Hook::Listener
	include RedmineSlack::Utils

	def controller_issues_new_after_save(context={})
		issue = context[:issue]

		channel = RedmineSlack::Payload::Channel.for_project(
			issue.project
		)
		url = RedmineSlack::Payload::Url.for_project(
			issue.project
		)

		return unless channel and url
		return if issue.is_private?

		msg = RedmineSlack::Payload::Message.new(
			issue: issue,
			notes: issue.description
		).msg

		attachment = RedmineSlack::Payload::Attachment.new(
			user: issue.author,
			notes: issue.description
		).attachment

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

		channel = RedmineSlack::Payload::Channel.for_project(
			issue.project
		)
		url = RedmineSlack::Payload::Url.for_project(
			issue.project
		)
		original_issue = context[:params][:original_issue]

		return unless channel and url and Setting.plugin_redmine_slack[:post_updates] == '1'
		return if issue.is_private?

		# Notify only if some properties updated
		# or if there's notes
		if original_issue
			keys = [:assigned_to_id, :priority_id, :status_id]
			changes = keys.map { |k|
				original_issue[k] == issue[k]
			}.include?(false)

			if !changes && journal.notes.blank?
				return nil
			end
		end

		msg = RedmineSlack::Payload::Message.new(
			issue: issue,
			notes: journal.notes
		).msg

		attachment = RedmineSlack::Payload::Attachment.new(
			user: journal.user,
			notes: journal.notes,
			details: journal.details
		).attachment

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

		channel = RedmineSlack::Payload::Channel.for_project(
			issue.project
		)
		url = RedmineSlack::Payload::Url.for_project(
			issue.project
		)
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

		attachment = RedmineSlack::Payload::Attachment.new(
			user: journal.user,
			notes: journal.notes,
			details: journal.details
		).attachment

		speak msg, channel, attachment, url
	end

	def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context={})
		issue = context[:issue]
		journal = issue.current_journal
		changeset = context[:changeset]

		channel = RedmineSlack::Payload::Channel.for_project(
			issue.project
		)
		url = RedmineSlack::Payload::Url.for_project(
			issue.project
		)

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

		attachment = RedmineSlack::Payload::Attachment.new(
			user: journal.user,
			details: journal.details,
			text: ll(
				Setting.default_language,
				:text_status_changed_by_changeset,
				"<#{revision_url}|#{escape changeset.comments}>"
			)
		).attachment

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
end
