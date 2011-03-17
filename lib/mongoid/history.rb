module Mongoid
  module History
    mattr_accessor :tracker_class_name
    mattr_accessor :trackable_classes
    mattr_accessor :trackable_class_options
    mattr_accessor :modifer_class_name
    
    def self.tracker_class
      @tracker_class ||= tracker_class_name.to_s.classify.constantize
    end

  end
end