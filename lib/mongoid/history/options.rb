module Mongoid
  module History
    class Options
      attr_reader :trackable, :options

      def initialize(trackable, opts = {})
        @trackable = trackable
        @options = default_options.merge(opts)
      end

      def scope
        trackable.collection_name.to_s.singularize.to_sym
      end

      def prepared
        @prepared ||= begin
          @prepared = options.dup
          prepare_skipped_fields
          prepare_formatted_fields
          parse_tracked_fields_and_relations
          @prepared
        end
      end

      private

      def default_options
        { on: :all,
          except: %i[created_at updated_at],
          tracker_class_name: nil,
          modifier_field: :modifier,
          version_field: :version,
          changes_method: :changes,
          scope: scope,
          track_create: true,
          track_update: true,
          track_destroy: true,
          format: nil }
      end

      # Sets the :except attributes and relations in `options` to be an [ Array <String> ]
      # The attribute names and relations are stored by their `database_field_name`s
      # Removes the `nil` and duplicate entries from skipped attributes/relations list
      def prepare_skipped_fields
        # normalize :except fields to an array of database field strings
        @prepared[:except] = Array(@prepared[:except])
        @prepared[:except] = @prepared[:except].map { |field| trackable.database_field_name(field) }.compact.uniq
      end

      def prepare_formatted_fields
        formats = {}

        if @prepared[:format].class == Hash
          @prepared[:format].each do |field, format|
            next if field.nil?

            field = trackable.database_field_name(field)

            if format.class == Hash && trackable.embeds_many?(field)
              relation_class = trackable.relation_class_of(field)
              formats[field] = format.inject({}) { |a, e| a.merge(relation_class.database_field_name(e.first) => e.last) }
            elsif format.class == Hash && trackable.embeds_one?(field)
              relation_class = trackable.relation_class_of(field)
              formats[field] = format.inject({}) { |a, e| a.merge(relation_class.database_field_name(e.first) => e.last) }
            else
              formats[field] = format
            end
          end
        end

        @prepared[:format] = formats
      end

      def parse_tracked_fields_and_relations
        # case `options[:on]`
        # when `posts: [:id, :title]`, then it will convert it to `[[:posts, [:id, :title]]]`
        # when `:foo`, then `[:foo]`
        # when `[:foo, { posts: [:id, :title] }]`, then return as is
        @prepared[:on] = Array(@prepared[:on])

        @prepared[:on] = @prepared[:on].map { |opt| opt == :all ? :fields : opt }

        if @prepared[:on].include?(:fields)
          @prepared[:on] = @prepared[:on].reject { |opt| opt == :fields }
          @prepared[:on] = @prepared[:on] | trackable.fields.keys.map(&:to_sym) - reserved_fields.map(&:to_sym)
        end

        if @prepared[:on].include?(:embedded_relations)
          @prepared[:on] = @prepared[:on].reject { |opt| opt == :embedded_relations }
          @prepared[:on] = @prepared[:on] | trackable.embedded_relations.keys
        end

        @prepared[:fields] = []
        @prepared[:dynamic] = []
        @prepared[:relations] = { embeds_one: {}, embeds_many: {} }

        @prepared[:on].each do |option|
          if option.is_a?(Hash)
            option.each { |k, v| split_and_categorize(k => v) }
          else
            split_and_categorize(option)
          end
        end
      end

      def split_and_categorize(field_and_options)
        field = get_database_field_name(field_and_options)
        field_options = get_field_options(field_and_options)
        categorize_tracked_option(field, field_options)
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
        return if @prepared[:except].include?(field)
        return if reserved_fields.include?(field)

        field_options = Array(field_options)

        if trackable.embeds_one?(field)
          track_relation(field, :embeds_one, field_options)
        elsif trackable.embeds_many?(field)
          track_relation(field, :embeds_many, field_options)
        elsif trackable.fields.keys.include?(field)
          @prepared[:fields] << field
        else
          @prepared[:dynamic] << field
        end
      end

      def track_relation(field, kind, field_options)
        relation_class = trackable.relation_class_of(field)
        @prepared[:relations][kind][field] = if field_options.blank?
                                               relation_class.fields.keys
                                             else
                                               %w[_id] | field_options.map { |opt| relation_class.database_field_name(opt) }
                                             end
      end

      def reserved_fields
        @reserved_fields ||= ['_id', '_type', @prepared[:version_field].to_s, "#{@prepared[:modifier_field]}_id"]
      end
    end
  end
end
