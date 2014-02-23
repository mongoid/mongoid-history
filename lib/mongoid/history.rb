require 'easy_diff'
require 'mongoid/compatibility'
require 'mongoid/history/version'
require 'mongoid/history/tracker'
require 'mongoid/history/trackable'

module Mongoid
  module History
    GLOBAL_TRACK_HISTORY_FLAG = 'mongoid_history_trackable_enabled'

    class << self
      attr_accessor :tracker_class_name
      attr_accessor :trackable_class_options
      attr_accessor :modifier_class_name
      attr_accessor :current_user_method

      def disable(&_block)
        store[GLOBAL_TRACK_HISTORY_FLAG] = false
        yield
      ensure
        store[GLOBAL_TRACK_HISTORY_FLAG] = true
      end

      def enabled?
        store[GLOBAL_TRACK_HISTORY_FLAG] != false
      end

      def store
        defined?(RequestStore) ? RequestStore.store : Thread.current
      end
    end
  end
end

Mongoid::History.modifier_class_name = 'User'
Mongoid::History.trackable_class_options = {}
Mongoid::History.current_user_method ||= :current_user
