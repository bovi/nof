require 'securerandom'

class Activities
  class << self
    def register(action, &block)
      own_actions[action] = block
    end

    def own_actions
      @own_actions ||= {}
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
    end

    def size
      (@activities || []).size
    end

    def to_json
      (@activities || []).to_json
    end

    def method_missing(method_name, *args, &block)
      if own_actions.key?(method_name.to_s)
        own_actions[method_name.to_s].call(*args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      own_actions.key?(method_name.to_s) || super
    end
  end
end
