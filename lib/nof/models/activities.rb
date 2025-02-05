module NOF
  class Activities
    extend DatabaseConfig

    def self.setup_tables(db)
      db.execute(<<-SQL)
        CREATE TABLE IF NOT EXISTS activities (
          id INTEGER PRIMARY KEY,
          activity_id TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          type TEXT NOT NULL,
          options TEXT NOT NULL,  -- JSON string
          created_at INTEGER DEFAULT (strftime('%s', 'now'))
        )
      SQL
    end

    def self.all
      activities = []
      db.execute("SELECT activity_id, timestamp, type, options FROM activities ORDER BY timestamp DESC") do |row|
        activity = {
          'activity_id' => row[0],
          'timestamp' => row[1],
          'action' => row[2],
          'opt' => JSON.parse(row[3])
        }
        activities << activity
      end
      activities
    end

    def self.any?
      db.get_first_value("SELECT EXISTS(SELECT 1 FROM activities)") == 1
    end

    def self.clean!
      db.execute("DELETE FROM activities")
    end

    def self.handle_activities(activities)
      activities.each do |activity|
        handler_class = case activity['action']
        when /^(add|delete)_task_template$/, /template_to_group$/
          ActivityHandlers::TaskTemplateHandler
        when /^(add|delete)_host$/, /host_to_group$/
          ActivityHandlers::HostHandler
        when /^(add|delete)_group$/
          ActivityHandlers::GroupHandler
        else
          raise "Unknown activity type: #{activity['action']}"
        end

        handler_class.handle_activity(activity)
      end
    end

    private

    def self.add(activity)
      activity_id = "#{Time.now.to_i}-#{SecureRandom.uuid}"
      # Create options hash without the action key
      options = activity.reject { |k,_| k == :action }
      db.execute(
        "INSERT INTO activities (activity_id, timestamp, type, options) VALUES (?, ?, ?, ?)",
        [activity_id, Time.now.to_i, activity[:action], options.to_json]
      )
    end

    # Define public methods that create standardized activities
    class << self
      def add_task_template(uuid, command, schedule, type, group_uuids, formatter)
        add({
          action: 'add_task_template',
          uuid: uuid,
          command: command,
          schedule: schedule,
          type: type,
          group_uuids: group_uuids,
          formatter: formatter
        })
      end

      def delete_task_template(uuid)
        add({
          action: 'delete_task_template',
          uuid: uuid
        })
      end

      def add_template_to_group(template_uuid, group_uuid)
        add({
          action: 'add_template_to_group',
          template_uuid: template_uuid,
          group_uuid: group_uuid
        })
      end

      def add_host(uuid, name, ip)
        add({
          action: 'add_host',
          uuid: uuid,
          name: name,
          ip: ip
        })
      end

      def delete_host(uuid)
        add({
          action: 'delete_host',
          uuid: uuid
        })
      end

      def add_host_to_group(host_uuid, group_uuid)
        debug("Adding host: '#{host_uuid}' to group: '#{group_uuid}'")
        add({
          action: 'add_host_to_group',
          host_uuid: host_uuid,
          group_uuid: group_uuid
        })
      end

      def add_group(uuid, name)
        add({
          action: 'add_group',
          uuid: uuid,
          name: name
        })
      end

      def delete_group(uuid)
        add({
          action: 'delete_group',
          uuid: uuid
        })
      end
    end
  end
end 