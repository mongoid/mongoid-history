module Mongoid
  module History
    class Options
      attr_reader :trackable, :options

      def initialize(trackable)
        @trackable = trackable
      end

      def scope
        trackable.collection_name.to_s.singularize.to_sym
      end

      def parse(options = {})
        @options = default_options.merge(options)
        prepare_skipped_fields
        parse_tracked_fields_and_relations
        @options
      end

      private

      def default_options
        @default_options ||=
          { on: :all,
            except: [:created_at, :updated_at],
            tracker_class_name: nil,
            modifier_field: :modifier,
            version_field: :version,
            changes_method: :changes,
            scope: scope,
            track_create: false,
            track_update: true,
            track_destroy: false }
      end

      # Sets the :except attributes and relations in `options` to be an [ Array <String> ]
      # The attribute names and relations are stored by their `database_field_name`s
      # Removes the `nil` and duplicate entries from skipped attributes/relations list
      def prepare_skipped_fields
        # normalize :except fields to an array of database field strings
        @options[:except] = Array(options[:except])
        @options[:except] = options[:except].map { |field| trackable.database_field_name(field) }.compact.uniq
      end

      def parse_tracked_fields_and_relations
        # case `options[:on]`
        # when `posts: [:id, :title]`, then it will convert it to `[[:posts, [:id, :title]]]`
        # when `:foo`, then `[:foo]`
        # when `[:foo, { posts: [:id, :title] }]`, then return as is
        @options[:on] = Array(options[:on])

        # # :all is just an alias to :fields for now, to support existing users of `mongoid-history`
        # # In future, :all will track all the fields and relations of trackable class
        if options[:on].include?(:all)
          warn "[DEPRECATION] Use :fields instead of :all to track all fields in class #{trackable}.\n\
            Going forward, :all will track all the fields and relations for the class"
        end

        @options[:on] = options[:on].map { |opt| (opt == :all) ? :fields : opt }

        if options[:on].include?(:fields)
          @options[:on] = options[:on].reject { |opt| opt == :fields }
          @options[:on] = options[:on] | trackable.fields.keys.map(&:to_sym) - reserved_fields.map(&:to_sym)
        end

        @options[:fields] = []
        @options[:dynamic] = []
        @options[:relations] = { embeds_one: {}, embeds_many: {} }

        options[:on].each do |option|
          field = get_database_field_name(option)
          field_options = get_field_options(option)
          categorize_tracked_option(field, field_options)
        end
      end

      # Returns the database_field_name key for tracked option
      #
      # @param [ String | Symbol | Array | Hash ] option The field or relation name to track
      #
      # @return [ String ] the database field name for tracked option
      def get_database_field_name(option)
        key = if option.is_a?(Hash)
                option.keys.first
              elsif option.is_a?(Array)
                option.first
              end
        trackable.database_field_name(key || option)
      end

      # Returns the tracked attributes for embedded relations, otherwise `nil`
      #
      # @param [ String | Symbol | Array | Hash ] option The field or relation name to track
      #
      # @return [ nil | Array <String | Symbol> ] the list of tracked fields for embedded relation
      def get_field_options(option)
        if option.is_a?(Hash)
          option.values.first
        elsif option.is_a?(Array)
          option.last
        end
      end

      # Tracks the passed option under:
      #   `fields`
      #   `dynamic`
      #   `relations -> embeds_one` or
      #   `relations -> embeds_many`
      #
      # @param [ String ] field The database field name of field or relation to track
      # @param [ nil | Array <String | Symbol> ] field_options The tracked fields for embedded relations
      def categorize_tracked_option(field, field_options = nil)
        return if options[:except].include?(field)
        return if reserved_fields.include?(field)

        field_options = Array(field_options)

        if trackable.embeds_one?(field)
          track_embeds_one(field, field_options)
        elsif trackable.embeds_many?(field)
          track_embeds_many(field, field_options)
        elsif trackable.fields.keys.include?(field)
          @options[:fields] << field
        else
          @options[:dynamic] << field
        end
      end

      def track_embeds_one(field, field_options)
        relation_class = trackable.embeds_one_class(field)
        @options[:relations][:embeds_one][field] = if field_options.blank?
                                                     relation_class.fields.keys
                                                   else
                                                     %w(_id) | field_options.map { |opt| relation_class.database_field_name(opt) }
                                                   end
      end

      def track_embeds_many(field, field_options)
        relation_class = trackable.embeds_many_class(field)
        @options[:relations][:embeds_many][field] = if field_options.blank?
                                                      relation_class.fields.keys
                                                    else
                                                      %w(_id) | field_options.map { |opt| relation_class.database_field_name(opt) }
                                                    end
      end

      def reserved_fields
        @reserved_fields ||= ['_id', '_type', options[:version_field].to_s, "#{options[:modifier_field]}_id"]
      end
    end
  end
end
