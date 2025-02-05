module NOF
  module ActivityHandlers
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
        Groups.add_task_template([activity['group_uuid']], activity['template_uuid'])
      end
    end
  end
end 