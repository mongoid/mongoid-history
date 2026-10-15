module Mongoid
  module History
    # Model-owned metadata, kept separate from canonical audit attributes.
    module TrackerAttributes
      RESERVED_ATTRIBUTES = %w[
        _id id _type association_chain scope version action original modified
        modifier modifier_id trackable created_at updated_at
      ].freeze

      private

      def custom_history_tracker_attributes(action)
        method = history_trackable_options[:tracker_attributes_method]
        return {} unless method

        attributes = send(method, action)
        raise ArgumentError, 'tracker_attributes_method must return a Hash' unless attributes.is_a?(Hash)

        attributes = attributes.stringify_keys
        raise ArgumentError, 'tracker_attributes_method cannot replace reserved history attributes' if (attributes.keys & RESERVED_ATTRIBUTES).any?

        attributes
      rescue StandardError
        clear_trackable_memoization
        raise
      end
    end
  end
end
