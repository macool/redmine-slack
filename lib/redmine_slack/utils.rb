module RedmineSlack
  module Utils
    def escape(msg)
      msg.to_s
         .gsub("&", "&amp;")
         .gsub("<", "&lt;")
         .gsub(">", "&gt;")
    end
  end
end
