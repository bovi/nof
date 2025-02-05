module NOF
  module ActivityHandlers
    class Base
      def self.handle_activity(activity)
        handler = "handle_#{activity['action']}".to_sym
        if respond_to?(handler)
          send(handler, activity)
        else
          fatal("Unknown activity action: #{activity['action']}")
          raise "Unknown activity action: #{activity['action']}"
        end
      end
    end
  end
end 