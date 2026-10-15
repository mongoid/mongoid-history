module Mongoid
  module History
    module Hooks
      # Opt-in Rails controller integration with request-scoped modifier cleanup.
      module Modifier
        extend ActiveSupport::Concern

        included do
          around_action :with_history_modifier
        end

        private

        def with_history_modifier(&block)
          Mongoid::History.with_modifier(send(Mongoid::History.current_user_method), &block)
        end
      end
    end
  end
end
