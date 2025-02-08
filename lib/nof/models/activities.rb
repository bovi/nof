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

    def add(uuid: nil, created_at: nil, action: nil, opt: {})
      @activities ||= []
      activity = {}
      activity[:uuid] = uuid || SecureRandom.uuid
      activity[:created_at] = created_at || Time.now.to_i
      raise ArgumentError, "action is required" unless action
      activity[:action] = action
      activity[:opt] = opt
      @activities << activity

      activity[:uuid]
    end

    def size
      (@activities || []).size
    end

    def to_json
      (@activities || []).to_json
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
        activity_uuid = add(action: method_name.to_s, opt: hsh)
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
