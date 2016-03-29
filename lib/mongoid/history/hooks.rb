module Mongoid
  module History
    module Hooks
      extend ActiveSupport::Concern

      included do
        before_action do |controller|
          Thread.current[:mongoid_history_controller] = controller
        end
      end
    end
  end
end
