module Mongoid::History
  class Sweeper < Mongoid::Observer
    attr_accessor :controller

    def self.observed_classes
      [Mongoid::History.tracker_class]
    end

    def before(controller)
      self.controller = controller
      true # before method from sweeper should always return true
    end

    def after(controller)
      self.controller = controller
      # Clean up, so that the controller can be collected after this request
      self.controller = nil
    end

    def before_create(track)
      track.modifier ||= current_user
    end

    def current_user
      controller.send Mongoid::History.current_user_method if controller.respond_to?(Mongoid::History.current_user_method, true)
    end
  end
end
