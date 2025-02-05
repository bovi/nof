module NOF
  module ActivityHandlers
    class HostHandler < Base
      def self.handle_add_host(activity)
        Hosts.add(activity['name'], activity['ip'], with_uuid: activity['uuid'])
      end

      def self.handle_delete_host(activity)
        Hosts.remove(activity['uuid'])
      end

      def self.handle_add_host_to_group(activity)
        Groups.add_host(activity['group_uuid'], activity['host_uuid'])
      end
    end
  end
end 