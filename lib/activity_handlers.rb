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

  class TaskTemplateHandler < Base
    def self.handle_add_task_template(activity)
      uuid = activity['uuid']
      command = activity['command']
      schedule = activity['schedule']
      type = activity['type']
      group_uuids = activity['group_uuids']
      formatter = activity['formatter']

      debug("Adding task template: #{uuid} #{command} #{schedule} #{type} #{group_uuids} #{formatter.inspect}")

      TaskTemplates.add(command, schedule, type, group_uuids, 
                       formatter: formatter, with_uuid: uuid)
    end

    def self.handle_delete_task_template(activity)
      TaskTemplates.remove(activity['uuid'])
    end

    def self.handle_add_template_to_group(activity)
      Groups.add_task_template(activity['group_uuids'], activity['template_uuid'])
    end
  end

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

  class GroupHandler < Base
    def self.handle_add_group(activity)
      Groups.add(activity['name'], with_uuid: activity['uuid'])
    end

    def self.handle_delete_group(activity)
      Groups.remove(activity['uuid'])
    end
  end
end 