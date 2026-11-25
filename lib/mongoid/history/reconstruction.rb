module Mongoid
  module History
    class IncompleteHistory < StandardError
    end

    # Replays recorded values, never supplementing them with today's document.
    class Reconstruction
      def initialize(tracks, current_version)
        @tracks = tracks.to_a.sort_by { |track| track.version || -1 }
        @current_version = current_version || 0
      end

      def at_version(version)
        raise ArgumentError, 'version must be a non-negative Integer' unless version.is_a?(Integer) && version >= 0

        validate!
        raise IncompleteHistory, "No recorded version #{version}" if version > @tracks.last.version

        replay(@tracks.select { |track| track.version <= version })
      end

      def at(time)
        raise ArgumentError, 'time must be a Time or ActiveSupport::TimeWithZone' unless time.is_a?(Time) ||
                                                                                         time.is_a?(ActiveSupport::TimeWithZone)

        validate!
        replay(@tracks.select { |track| track.created_at <= time })
      end

      private

      def validate!
        raise IncompleteHistory, 'Reconstruction requires a recorded create at version 1' unless @tracks.first && @tracks.first.action == 'create' && @tracks.first.version == 1
        raise IncompleteHistory, 'The current document version is newer than the retained history' if @tracks.last.version < @current_version

        @tracks.each_with_index do |track, index|
          raise IncompleteHistory, 'History has missing, duplicate, or invalid tracks' unless track.version == index + 1 && %w[create update destroy].include?(track.action) && track.created_at
          next if index.zero?

          previous = @tracks[index - 1]
          raise IncompleteHistory, 'History has inconsistent timestamps or lifecycle actions' if track.created_at < previous.created_at || track.action == 'create' || previous.action == 'destroy'
        end
      end

      def replay(tracks)
        return if tracks.empty? || tracks.last.action == 'destroy'

        tracks.each_with_object({}) do |track, attributes|
          attributes.easy_unmerge!(track.original.deep_dup)
          attributes.easy_merge!(track.modified.deep_dup)
        end
      end
    end
  end
end
