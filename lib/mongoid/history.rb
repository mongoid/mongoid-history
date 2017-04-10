require 'easy_diff'
require 'mongoid/compatibility'
require 'mongoid/history/attributes/base'
require 'mongoid/history/attributes/create'
require 'mongoid/history/attributes/update'
require 'mongoid/history/attributes/destroy'
require 'mongoid/history/hooks/modifier'
require 'mongoid/history/options'
require 'mongoid/history/version'
require 'mongoid/history/tracker'
require 'mongoid/history/trackable'

module Mongoid
  module History
    GLOBAL_TRACK_HISTORY_FLAG = 'mongoid_history_trackable_enabled'.freeze

    class << self
      attr_accessor :tracker_class_name
      attr_accessor :trackable_class_options
      attr_accessor :trackable_settings
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

      def default_settings
        @default_settings ||= { paranoia_field: 'deleted_at' }
      end

      def trackable_class_settings(trackable_class)
        trackable_settings[trackable_class.name.to_sym] || default_settings
      end
    end
  end
end

Mongoid::History.modifier_class_name = 'User'
Mongoid::History.trackable_class_options = {}
Mongoid::History.trackable_settings = {}
Mongoid::History.current_user_method ||= :current_user
