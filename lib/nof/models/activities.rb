require 'securerandom'

# Track changes in the systems (called activities)
# Every change in the system is tracked
# This is necessary for audit the interaction
# but also to synchronize the systems
# e.g. a change on the Dashboard should be reflected
# on the Controller and the RemoteDashboard
class Activities < Model
  class << self
    def setup_tables
      create_table('activities', [
        'uuid',
        'created_at',
        'action',
        'opt',
        'source_name'
      ])

      create_table('activities_northbound', [
        'uuid',
        'created_at',
        'action',
        'opt',
        'source_name'
      ])

      create_table('activities_southbound', [
        'uuid',
        'created_at',
        'action',
        'opt',
        'source_name'
      ])
    end

    def register(action, &block)
      own_actions[action] = block
    end

    def own_actions
      @own_actions ||= {}
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM activities WHERE uuid = ?", uuid)
      ret = ret.map do |row|
        row = row.transform_keys(&:to_sym)
        row[:opt] = JSON.parse(row[:opt]).transform_keys(&:to_sym)
        row
      end
      ret.first
    end

    # add an activity to the activities
    #
    # uuid: the uuid of the activity (optional if we sync)
    # created_at: the timestamp of the activity (optional if we sync)
    # action: the action of the activity (mandatory)
    # opt: the options of the activity
    # source: :northbound or :southbound (the sync source - only if we sync)
    # source_name: the name of the source (optional if we sync)
    def add(uuid: nil, created_at: nil, action: nil, opt: {}, sync_source: nil, source_name: nil)
      activity = {}
      activity[:uuid] = uuid || SecureRandom.uuid
      activity[:created_at] = created_at || Time.now.to_i
      raise ArgumentError, "action is required" unless action
      activity[:action] = action
      activity[:opt] = opt
      _source_name = source_name || $system_name

      db.execute("INSERT INTO activities (uuid, created_at, action, opt, source_name) VALUES (?, ?, ?, ?, ?)",
                 activity[:uuid], activity[:created_at], activity[:action], activity[:opt].to_json, _source_name)

      # here we prepare the activities to be synced for the
      # southbound or northbound system
      #
      # IMPORTANT:
      # only add to the northbound or southbound activities
      # if the source is not the same as the target system
      # otherwise we push the same activity back to the system
      # where it came from.
      # If there is no northbound or southbound system, we don't
      # need to sync either.
      if sync_source != :northbound && $northbound_system_name != nil
        db.execute("INSERT INTO activities_northbound (uuid, created_at, action, opt, source_name) VALUES (?, ?, ?, ?, ?)",
                   activity[:uuid], activity[:created_at], activity[:action], activity[:opt].to_json, _source_name)
      end
      if sync_source != :southbound && $southbound_system_name != nil
        db.execute("INSERT INTO activities_southbound (uuid, created_at, action, opt, source_name) VALUES (?, ?, ?, ?, ?)",
                   activity[:uuid], activity[:created_at], activity[:action], activity[:opt].to_json, _source_name)
      end

      activity[:uuid]
    end

    # sync activities from another system
    #
    # activities: the activities to sync
    # sync_source: :northbound or :southbound (the sync source)
    def sync(activities, sync_source: nil)
      raise ArgumentError, "sync_source is required" unless sync_source

      activities.each do |activity|
        if self[activity['uuid']]
          err "activity already exists: #{activity['uuid']}"
          raise ArgumentError, "activity already exists: #{activity['uuid']}"
        end
        opt = activity['opt'].transform_keys(&:to_sym) if activity['opt'].is_a?(Hash)
        if opt
          opt = opt.transform_keys(&:to_sym)
          opt.each do |k, v|
            if v.is_a?(Hash)
              opt[k] = v.transform_keys(&:to_sym)
            end
          end
        end
        ret = own_actions[activity['action']].call(opt)
        ret = add(
          uuid: activity['uuid'],
          created_at: activity['created_at'],
          action: activity['action'],
          opt: opt,
          sync_source: sync_source,
          source_name: activity['source_name']
        )
      end
      activities.size
    end

    def size
      count("activities")
    end

    def to_json
      db.execute("SELECT * FROM activities").map do |row|
        row = row.transform_keys(&:to_sym)
        row[:opt] = JSON.parse(row[:opt]).transform_keys(&:to_sym)
        row
      end.to_json
    end

    def northbound_json! &block
      json = db.execute("SELECT * FROM activities_northbound").map do |row|
        row = row.transform_keys(&:to_sym)
        row[:opt] = JSON.parse(row[:opt]).transform_keys(&:to_sym)
        row
      end.to_json
      yield json
      db.execute("DELETE FROM activities_northbound")
    end

    def northbound_activities
      db.execute("SELECT * FROM activities_northbound")
    end

    def southbound_activities
      db.execute("SELECT * FROM activities_southbound")
    end

    def southbound_json! &block
      json = db.execute("SELECT * FROM activities_southbound").map do |row|
        row = row.transform_keys(&:to_sym)
        row[:opt] = JSON.parse(row[:opt]).transform_keys(&:to_sym)
        row
      end.to_json
      yield json
      db.execute("DELETE FROM activities_southbound")
    end

    def southbound_raw!
      raw = db.execute("SELECT * FROM activities_southbound")
      raw = raw.map do |row|
        row = row.transform_keys(&:to_sym)
        row[:opt] = JSON.parse(row[:opt]).transform_keys(&:to_sym)
        row
      end
      db.execute("DELETE FROM activities_southbound")
      raw
    end

    # call registered action
    #
    # return array with:
    # - uuid of the activity
    # - result of the action
    def method_missing(method_name, *args, &block)
      if own_actions.key?(method_name.to_s)
        hsh = args.first || {}
        hsh = hsh.transform_keys(&:to_sym) if hsh.is_a?(Hash)
        result = own_actions[method_name.to_s].call(hsh, &block)
        activity_uuid = add(action: method_name.to_s, opt: result)
        [activity_uuid, result]
      else
        # action not registered
        super
      end
    end

    # implement respond_to_missing? to make
    # this class behave like all registered
    # actions are real methods
    def respond_to_missing?(method_name, include_private = false)
      own_actions.key?(method_name.to_s) || super
    end
  end
end
