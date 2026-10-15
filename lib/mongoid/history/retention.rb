module Mongoid
  module History
    # Per-document deletion of old revisions.
    module Retention
      def self.validate_limit!(limit)
        return if limit.nil? || (limit.is_a?(Integer) && limit >= 0)

        raise ArgumentError, 'max_history must be nil or a non-negative Integer'
      end

      # Permanently discard older history for this document only.
      # Run separately from persistence, with concurrent writers coordinated by the caller.
      def prune_history!(keep:)
        raise ArgumentError, 'keep must be a non-negative Integer' unless keep.is_a?(Integer) && keep >= 0
        raise ArgumentError, 'cannot prune history for an unsaved document' if new_record?

        tracks = self.class.tracker_class.where(scope: related_scope, association_chain: traverse_association_chain)
        stale_ids = tracks.desc(:version, :_id).skip(keep).pluck(:_id)
        return 0 if stale_ids.empty?

        @history_tracks = nil
        tracks.where(:_id.in => stale_ids).delete_all
      end

      private

      def schedule_history_retention
        keep = history_trackable_options[:max_history]
        return if keep.nil?

        frames = history_retention_root.instance_variable_get(:@mongoid_history_retention_frames)
        if frames&.any?
          frames.last << [self, keep]
        else
          prune_history!(keep: keep)
        end
      end
    end

    # Delay destructive maintenance until the enclosing callback-based write succeeds.
    module RetentionLifecycle
      def run_callbacks(kind, *args, &block)
        return super unless %i[create update save destroy].include?(kind)

        with_history_retention { super }
      end
      ruby2_keywords(:run_callbacks) if respond_to?(:ruby2_keywords, true)

      private

      def history_retention_root
        document = self
        document = document._parent while document._parent
        document
      end

      def with_history_retention
        root = history_retention_root
        frames = root.instance_variable_get(:@mongoid_history_retention_frames) || []
        root.instance_variable_set(:@mongoid_history_retention_frames, frames)
        pending = []
        frames << pending
        begin
          result = yield
        ensure
          frames.pop
          root.instance_variable_set(:@mongoid_history_retention_frames, nil) if frames.empty?
        end
        if result != false
          if frames.empty?
            pending.uniq.each { |document, keep| document.prune_history!(keep: keep) }
          else
            frames.last.concat(pending)
          end
        end
        result
      end
    end
  end
end
