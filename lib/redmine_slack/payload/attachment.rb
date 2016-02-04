module RedmineSlack
  module Payload
    class Attachment
      include ERB::Util
      include RedmineSlack::Utils
      include GravatarHelper::PublicMethods

      attr_reader :user,
                  :text,
                  :notes,
                  :details

      def initialize(opts)
        opts.each do |k, v|
          instance_variable_set "@#{k}", v
        end
      end

      def attachment
        {
          author_name: escape(user)
        }.tap do |attachment|
          attachment[:text] = escape(notes) if notes.present?
          attachment[:text] = text if text.present?
          attachment[:fields] = fields if details.present?
          attachment[:author_icon] = gravatar if gravatar.present?
        end
      end

      private

      def gravatar
        gravatar_url(user.mail, size: 32)
      end

      def fields
        RedmineSlack::Payload::AttachmentFields.new(
          details
        ).fields
      end
    end
  end
end
