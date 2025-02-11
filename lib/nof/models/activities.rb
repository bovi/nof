require 'securerandom'

# Track changes in the systems (called activities)
# Every change in the system is tracked
# This is necessary for audit the interaction
# but also to synchronize the systems
# e.g. a change on the Dashboard should be reflected
# on the Controller and the RemoteDashboard
class Activities
  class << self
    def register(action, &block)
      own_actions[action] = block
    end

    def own_actions
      @own_actions ||= {}
    end

    def [](uuid)
      (@activities || []).find { |a| a[:uuid] == uuid }
    end

    # add an activity to the activities
    #
    # uuid: the uuid of the activity (optional if we sync)
    # created_at: the timestamp of the activity (optional if we sync)
    # action: the action of the activity (mandatory)
    # opt: the options of the activity
    # from: :northbound or :southbound (the sync source - only if we sync)
    def add(uuid: nil, created_at: nil, action: nil, opt: {}, from: nil)
      @activities ||= []
      @northbound_activities ||= []
      @southbound_activities ||= []

      activity = {}
      activity[:uuid] = uuid || SecureRandom.uuid
      activity[:created_at] = created_at || Time.now.to_i
      raise ArgumentError, "action is required" unless action
      activity[:action] = action
      activity[:opt] = opt

      @activities << activity

      # here we prepare the activities to be synced for the
      # southbound or northbound system
      #
      # IMPORTANT:
      # only add to the northbound or southbound activities
      # if the source is not the same as the target system
      @northbound_activities << activity unless from == :northbound
      @southbound_activities << activity unless from == :southbound

      activity[:uuid]
    end

    # sync activities from another system
    #
    # activities: the activities to sync
    # from: :northbound or :southbound (the sync source)
    def sync(activities, from: nil)
      raise ArgumentError, "from is required" unless from
      debug "syncing activities from #{from}"

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
          from: from
        )
      end
      activities.size
    end

    def size
      (@activities || []).size
    end

    def to_json
      (@activities || []).to_json
    end

    def northbound_json! &block
      json = (@northbound_activities || []).to_json
      yield json
      @northbound_activities = []
    end

    def southbound_json! &block
      json = (@southbound_activities || []).to_json
      @southbound_activities = []
      json
    end

    def southbound_raw!
      raw = (@southbound_activities || [])
      @southbound_activities = []
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
