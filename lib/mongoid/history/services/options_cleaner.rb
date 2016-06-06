module Mongoid
  module History
    class OptionsCleaner
      attr_reader :trackable, :options

      def initialize(trackable, options = {})
        @trackable = trackable
        @options = default_options.merge(options)
      end

      def scope
        trackable.collection_name.to_s.singularize.to_sym
      end

      # Options
      #   :on
      #     - :all OR [:all] OR :fields OR [:fields] - track all fields for now
      #     - :foo OR [:foo, ...] - track specified fields
      #     - [:<association_name>, ...] - track only specified associations
      #     - [:all, :<association_name>, ...] OR [:foo, ..., :<association_name>, ...] - combination of above
      def default_options
        { on: :all,
          except: [:created_at, :updated_at],
          modifier_field: :modifier,
          version_field: :version,
          changes_method: :changes,
          scope: scope,
          track_create: false,
          track_update: true,
          track_destroy: false }
      end

      def clean
        prepare_skipped_fields
        prepare_tracked_fields_and_relations
        options
      end

      def prepare_skipped_fields
        # normalize :except fields to an array of database field strings
        @options[:except] = Array(options[:except])
        @options[:except] = options[:except].map { |field| trackable.database_field_name(field) }.compact.uniq
      end

      def prepare_tracked_fields_and_relations
        @options[:on] = Array(options[:on])

        # :all is just an alias to :fields for now, to support existing users of `mongoid-history`
        # In future, :all will track all the fields and associations of trackable class
        @options[:on] = options[:on].map { |opt| (opt == :all) ? :fields : opt }
        @options[:on] = options[:on].map { |opt| trackable.database_field_name(opt) }.compact.uniq

        if @options[:on].include?('fields')
          @options[:tracked_fields] = trackable.fields.keys
          @options[:tracked_relations] = options[:on].reject { |opt| opt == 'fields' }
        else
          tracked_fields_and_relations = options[:on] - options[:except]
          @options[:tracked_fields] = trackable.fields.keys.select { |field| tracked_fields_and_relations.include?(field) }
          @options[:tracked_relations] = tracked_fields_and_relations - options[:tracked_fields]
        end

        @options[:tracked_fields] = options[:tracked_fields] - options[:except]
        @options[:tracked_relations] = options[:tracked_relations] - options[:except]
      end

      def self.clean(trackable, options = {})
        new(trackable, options).clean
      end
    end
  end
end
