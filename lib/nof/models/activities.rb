require 'securerandom'

# Track changes in the systems (called activities)
# Every change in the system is tracked
# This is necessary for audit the interaction
# but also to synchronize the systems
# e.g. a change on the Dashboard should be reflected
# on the Controller and the RemoteDashboard
class Activities < Model
  class << self
    # the opts field is a json field
    def setup_tables
      create_table('activities', [
        'uuid',
        'created_at',
        'action',
        'opts',
        'source_name'
      ])

      create_table('activities_northbound', [
        'uuid',
        'created_at',
        'action',
        'opts',
        'source_name'
      ])

      create_table('activities_southbound', [
        'uuid',
        'created_at',
        'action',
        'opts',
        'source_name'
      ])
    end

    def register(action, &block)
      own_actions[action] = block
    end

    def own_actions
      @own_actions ||= {}
    end

    # handle the json opts field
    def transform_row(row)
      row['opts'] = JSON.parse(row['opts']) if row && row['opts']
      row
    end

    def [](uuid)
      ret = db.execute("SELECT * FROM activities WHERE uuid = '#{sanitize_uuid(uuid)}' LIMIT 1")
      transform_row(ret.first)
    end

    # add an activity to the activities
    #
    # uuid: the uuid of the activity (optional if we sync)
    # created_at: the timestamp of the activity (optional if we sync)
    # action: the action of the activity (mandatory)
    # opt: the options of the activity
    # source: :northbound or :southbound (the sync source - only if we sync)
    # source_name: the name of the source (optional if we sync)
    def add(hsh)
      activity = {}
      activity['uuid'] = hsh['uuid'] || SecureRandom.uuid
      activity['created_at'] = hsh['created_at'] || (Time.now.to_f * 1000).to_i
      raise ArgumentError, "action is required" unless hsh['action']
      activity['action'] = hsh['action']
      activity['opts'] = hsh['opts']
      _source_name = hsh['source_name'] || $system_name

      db.execute("INSERT INTO activities (uuid, created_at, action, opts, source_name) VALUES (?, ?, ?, ?, ?)",
                 sanitize_uuid(activity['uuid']),
                 activity['created_at'],
                 activity['action'],
                 activity['opts'].to_json,
                 _source_name)

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
      if hsh['sync_source'] != :northbound && $northbound_system_name != nil
        db.execute("INSERT INTO activities_northbound (uuid, created_at, action, opts, source_name) VALUES (?, ?, ?, ?, ?)",
                   sanitize_uuid(activity['uuid']),
                   activity['created_at'],
                   activity['action'],
                   activity['opts'].to_json,
                   _source_name)
      end
      if hsh['sync_source'] != :southbound && $southbound_system_name != nil
        db.execute("INSERT INTO activities_southbound (uuid, created_at, action, opts, source_name) VALUES (?, ?, ?, ?, ?)",
                   sanitize_uuid(activity['uuid']),
                   activity['created_at'],
                   activity['action'],
                   activity['opts'].to_json,
                   _source_name)
      end

      activity['uuid']
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
        own_actions[activity['action']].call(activity['opts'])
        add(
          'uuid' => activity['uuid'],
          'created_at' => activity['created_at'],
          'action' => activity['action'],
          'opts' => activity['opts'],
          'sync_source' => sync_source,
          'source_name' => activity['source_name']
        )
      end
      activities.size
    end

    def size
      count("activities")
    end

    def each(&block)
      db.execute("SELECT * FROM activities ORDER BY created_at DESC").each do |row|
        block.call(transform_row(row))
      end
    end

    def to_json
      db.execute("SELECT * FROM activities").map do |row|
        transform_row(row)
      end.to_json
    end

    def northbound_json! &block
      json = db.execute("SELECT * FROM activities_northbound").map do |row|
        transform_row(row)
      end.to_json
      yield json
      db.execute("DELETE FROM activities_northbound")
    end

    def northbound_activities
      db.execute("SELECT * FROM activities_northbound").map do |row|
        transform_row(row)
      end
    end

    def southbound_activities
      db.execute("SELECT * FROM activities_southbound").map do |row|
        transform_row(row)
      end
    end

    def southbound_json! &block
      json = db.execute("SELECT * FROM activities_southbound").map do |row|
        transform_row(row)
      end.to_json
      yield json
      db.execute("DELETE FROM activities_southbound")
    end

    def southbound_raw!
      raw = db.execute("SELECT * FROM activities_southbound")
      raw = raw.map do |row|
        transform_row(row)
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
        result = own_actions[method_name.to_s].call(hsh, &block)
        activity_uuid = add('action' => method_name.to_s, 'opts' => result)
        [activity_uuid, result]
      else
        raise NotImplementedError, "Activity '#{method_name}' is not registered"
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
