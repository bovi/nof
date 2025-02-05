module NOF
  module ActivityHandlers
    class GroupHandler < Base
      def self.handle_add_group(activity)
        Groups.add(activity['name'], with_uuid: activity['uuid'])
      end

      def self.handle_delete_group(activity)
        Groups.remove(activity['uuid'])
      end
    end
  end
end 