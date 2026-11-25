module Mongoid
  module History
    # Read-only recorded values.
    module HistoricalAttributes
      def attributes_at(time)
        recorded_attributes.at(time)
      end

      def attributes_at_version(version)
        recorded_attributes.at_version(version)
      end

      private

      def recorded_attributes
        Mongoid::History::Reconstruction.new(history_tracks, send(history_trackable_options[:version_field]))
      end
    end
  end
end
