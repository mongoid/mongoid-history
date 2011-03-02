module Mongoid::History
  module Trackable
    extend ActiveSupport::Concern
    
    module ClassMethods
      def track_history(options)
        Mongoid::History.trackable_classes ||= []
        Mongoid::History.trackable_classes << self
      end
    end
  end
end