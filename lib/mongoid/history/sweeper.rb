module Mongoid::History
  class Sweeper < Mongoid::Observer
    def controller
      Thread.current[:mongoid_history_sweeper_controller]
    end

    def controller=(value)
      Thread.current[:mongoid_history_sweeper_controller] = value
    end

    def self.observed_classes
      [Mongoid::History.tracker_class]
    end

    # Hook to ActionController::Base#around_filter.
    # Runs before a controller action is run.
    # It should always return true so controller actions
    # can continue.
    def before(controller)
      self.controller = controller
      true
    end

    # Hook to ActionController::Base#around_filter.
    # Runs after a controller action is run.
    # Clean up so that the controller can
    # be collected after this request
    def after(controller)
      self.controller = nil
    end

    def before_create(track)
      modifier_field = track.trackable.history_trackable_options[:modifier_field]
      modifier = track.send modifier_field
      track.send "#{modifier_field}=", current_user unless modifier

      # set wrapper object to fetch history tracks by wrapper object
      track.wrapper_object = {class_name: controller.try(:controller_name).try(:classify), id: controller.try(:params).try(:[], :id)}
      # set history_group_id to group history tracks if given otherwise set to current time with minutes precision
      track.history_group_id = controller.try(:history_group_id) || Time.now.utc.strftime('%Y%m%d%H%M')
    end

    def current_user
      if controller.respond_to?(Mongoid::History.current_user_method, true)
        controller.send Mongoid::History.current_user_method
      end
    end
  end
end
