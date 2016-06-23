module Mongoid
  module History
    module Trackable
      extend ActiveSupport::Concern

      module ClassMethods
        def track_history(options = {})
          options_cleaner = Mongoid::History::OptionsCleaner.new(self)
          options = options_cleaner.clean(options)

          field options[:version_field].to_sym, type: Integer

          belongs_to_modifier_options = { class_name: Mongoid::History.modifier_class_name }
          belongs_to_modifier_options[:inverse_of] = options[:modifier_field_inverse_of] if options.key?(:modifier_field_inverse_of)
          belongs_to options[:modifier_field].to_sym, belongs_to_modifier_options

          include MyInstanceMethods
          extend SingletonMethods

          delegate :history_trackable_options, to: 'self.class'
          delegate :track_history?, to: 'self.class'

          before_update :track_update if options[:track_update]
          before_create :track_create if options[:track_create]
          before_destroy :track_destroy if options[:track_destroy]

          Mongoid::History.trackable_class_options ||= {}
          Mongoid::History.trackable_class_options[options_cleaner.scope] = options
        end

        def track_history?
          Mongoid::History.enabled? && Thread.current[track_history_flag] != false
        end

        def dynamic_enabled?
          Mongoid::Compatibility::Version.mongoid3? || (self < Mongoid::Attributes::Dynamic).present?
        end

        def disable_tracking(&_block)
          Thread.current[track_history_flag] = false
          yield
        ensure
          Thread.current[track_history_flag] = true
        end

        def track_history_flag
          "mongoid_history_#{name.underscore}_trackable_enabled".to_sym
        end
      end

      module MyInstanceMethods
        def history_tracks
          @history_tracks ||= Mongoid::History.tracker_class.where(
            scope: related_scope,
            association_chain: association_hash
          ).asc(:version)
        end

        #  undo :from => 1, :to => 5
        #  undo 4
        #  undo :last => 10
        def undo(modifier = nil, options_or_version = nil)
          versions = get_versions_criteria(options_or_version).to_a
          versions.sort! { |v1, v2| v2.version <=> v1.version }

          versions.each do |v|
            undo_attr = v.undo_attr(modifier)
            if Mongoid::Compatibility::Version.mongoid3? # update_attributes! not bypassing rails 3 protected attributes
              assign_attributes(undo_attr, without_protection: true)
            else # assign_attributes with 'without_protection' option does not work with rails 4/mongoid 4
              self.attributes = undo_attr
            end
          end
        end

        #  undo! :from => 1, :to => 5
        #  undo! 4
        #  undo! :last => 10
        def undo!(modifier = nil, options_or_version = nil)
          undo(modifier, options_or_version)
          save!
        end

        def redo!(modifier = nil, options_or_version = nil)
          versions = get_versions_criteria(options_or_version).to_a
          versions.sort! { |v1, v2| v1.version <=> v2.version }

          versions.each do |v|
            redo_attr = v.redo_attr(modifier)
            if Mongoid::Compatibility::Version.mongoid3?
              assign_attributes(redo_attr, without_protection: true)
              save!
            else
              update_attributes!(redo_attr)
            end
          end
        end

        def get_embedded(name)
          send(self.class.embedded_alias(name))
        end

        def create_embedded(name, value)
          send("create_#{self.class.embedded_alias(name)}!", value)
        end

        private

        def get_versions_criteria(options_or_version)
          if options_or_version.is_a? Hash
            options = options_or_version
            if options[:from] && options[:to]
              lower = options[:from] >= options[:to] ? options[:to] : options[:from]
              upper = options[:from] < options[:to] ? options[:to] : options[:from]
              versions = history_tracks.where(:version.in => (lower..upper).to_a)
            elsif options[:last]
              versions = history_tracks.limit(options[:last])
            else
              fail 'Invalid options, please specify (:from / :to) keys or :last key.'
            end
          else
            options_or_version = options_or_version.to_a if options_or_version.is_a?(Range)
            version_field_name = history_trackable_options[:version_field]
            version = options_or_version || attributes[version_field_name] || attributes[version_field_name.to_s]
            version = [version].flatten
            versions = history_tracks.where(:version.in => version)
          end
          versions.desc(:version)
        end

        def related_scope
          scope = history_trackable_options[:scope]

          # Use top level document if its name is specified in the scope
          root_document_name = traverse_association_chain.first['name'].singularize.underscore.tr('/', '_').to_sym
          if scope.is_a?(Array) && scope.include?(root_document_name)
            scope = root_document_name
          else
            scope = _parent.collection_name.to_s.singularize.to_sym if scope.is_a?(Array)
            if Mongoid::Compatibility::Version.mongoid3?
              scope = metadata.inverse_class_name.tableize.singularize.to_sym if metadata.present? && scope == metadata.as
            else
              scope = relation_metadata.inverse_class_name.tableize.singularize.to_sym if relation_metadata.present? && scope == relation_metadata.as
            end
          end

          scope
        end

        def traverse_association_chain(node = self)
          list = node._parent ? traverse_association_chain(node._parent) : []
          list << association_hash(node)
          list
        end

        def association_hash(node = self)
          # We prefer to look up associations through the parent record because
          # we're assured, through the object creation, it'll exist. Whereas we're not guarenteed
          # the child to parent (embedded_in, belongs_to) relation will be defined
          if node._parent
            meta = node._parent.relations.values.find do |relation|
              if Mongoid::Compatibility::Version.mongoid3?
                relation.class_name == node.metadata.class_name.to_s && relation.name == node.metadata.name
              else
                relation.class_name == node.relation_metadata.class_name.to_s &&
                relation.name == node.relation_metadata.name
              end
            end
          end

          # if root node has no meta, and should use class name instead
          name = meta ? meta.key.to_s : node.class.name

          ActiveSupport::OrderedHash['name', name, 'id', node.id]
        end

        # Returns a Hash of field name to pairs of original and modified values
        # for each tracked field for a given action.
        #
        # @param [ String | Symbol ] action The modification action (:create, :update, :destroy)
        #
        # @return [ Hash<String, Array<Object>> ] the pairs of original and modified
        #   values for each field
        def modified_attributes_for_action(action)
          case action.to_sym
          when :destroy then modified_attributes_for_destroy
          when :create then modified_attributes_for_create
          else modified_attributes_for_update
          end
        end

        def modified_attributes_for_update
          @modified_attributes_for_update ||= send(history_trackable_options[:changes_method]).select { |k, _| self.class.tracked?(k, :update) }
        end

        def modified_attributes_for_create
          return @modified_attributes_for_create if @modified_attributes_for_create
          aliased_fields = self.class.aliased_fields
          attrs = {}
          attributes.each { |k, v| attrs[k] = [nil, v] if self.class.tracked_field?(k, :create) }

          self.class.tracked_embedded_one
            .map { |rel| aliased_fields.key(rel) || rel }
            .each do |rel|
              obj = send(rel)
              attrs[rel] = [nil, obj.attributes] if obj
            end

          self.class.tracked_embedded_many
            .map { |rel| aliased_fields.key(rel) || rel }
            .each { |rel| attrs[rel] = [nil, send(rel).map(&:attributes)] }

          @modified_attributes_for_create = attrs
        end

        def modified_attributes_for_destroy
          return @modified_attributes_for_destroy if @modified_attributes_for_destroy
          aliased_fields = self.class.aliased_fields
          attrs = {}
          attributes.each { |k, v| attrs[k] = [v, nil] if self.class.tracked_field?(k, :destroy) }

          self.class.tracked_embedded_one
            .map { |rel| aliased_fields.key(rel) || rel }
            .each do |rel|
              obj = send(rel)
              attrs[rel] = [obj.attributes, nil] if obj
            end

          self.class.tracked_embedded_many
            .map { |rel| aliased_fields.key(rel) || rel }
            .each { |rel| attrs[rel] = [send(rel).map(&:attributes), nil] }

          @modified_attributes_for_destroy = attrs
        end

        def history_tracker_attributes(action)
          return @history_tracker_attributes if @history_tracker_attributes

          @history_tracker_attributes = {
            association_chain: traverse_association_chain,
            scope: related_scope,
            modifier: send(history_trackable_options[:modifier_field])
          }

          original, modified = transform_changes(modified_attributes_for_action(action))

          @history_tracker_attributes[:original] = original
          @history_tracker_attributes[:modified] = modified
          @history_tracker_attributes
        end

        def track_create
          track_history_for_action(:create)
        end

        def track_update
          track_history_for_action(:update)
        end

        def track_destroy
          track_history_for_action(:destroy)
        end

        def clear_trackable_memoization
          @history_tracker_attributes = nil
          @modified_attributes_for_create = nil
          @modified_attributes_for_update = nil
          @history_tracks = nil
        end

        def transform_changes(changes)
          original = {}
          modified = {}
          changes.each_pair do |k, v|
            o, m = v
            original[k] = o unless o.nil?
            modified[k] = m unless m.nil?
          end

          [original, modified]
        end

        protected

        def track_history_for_action?(action)
          track_history? && !(action.to_sym == :update && modified_attributes_for_update.blank?)
        end

        def track_history_for_action(action)
          if track_history_for_action?(action)
            current_version = (send(history_trackable_options[:version_field]) || 0) + 1
            send("#{history_trackable_options[:version_field]}=", current_version)
            Mongoid::History.tracker_class.create!(history_tracker_attributes(action.to_sym).merge(version: current_version, action: action.to_s, trackable: self))
          end
          clear_trackable_memoization
        end
      end

      module SingletonMethods
        # Whether or not the field or embedded relation should be tracked.
        #
        # @param [ String | Symbol ] field_or_relation The name or alias of the field OR the name of embedded relation
        # @param [ String | Symbol ] action The optional action name (:create, :update, or :destroy)
        #
        # @return [ Boolean ] whether or not the field or embedded relation is tracked for the given action
        def tracked?(field_or_relation, action = :update)
          tracked_field?(field_or_relation, action) || tracked_relation?(field_or_relation)
        end

        # Whether or not the field should be tracked.
        #
        # @param [ String | Symbol ] field The name or alias of the field
        # @param [ String | Symbol ] action The optional action name (:create, :update, or :destroy)
        #
        # @return [ Boolean ] whether or not the field is tracked for the given action
        def tracked_field?(field, action = :update)
          dynamic_field?(field) || tracked_fields_for_action(action).include?(database_field_name(field))
        end

        # Checks if field is dynamic.
        #
        # @param [ String | Symbol ] field The name of the dynamic field
        #
        # @return [ Boolean ] whether or not the field is dynamic
        def dynamic_field?(field)
          dynamic_enabled? && !fields.keys.include?(database_field_name(field))
        end

        # Retrieves the list of tracked fields for a given action.
        #
        # @param [ String | Symbol ] action The action name (:create, :update, or :destroy)
        #
        # @return [ Array < String > ] the list of tracked fields for the given action
        def tracked_fields_for_action(action)
          case action.to_sym
          when :destroy then tracked_fields + reserved_tracked_fields
          else tracked_fields
          end
        end

        # Retrieves the memoized base list of tracked fields, and associations excluding reserved fields.
        #
        # @return [ Array < String > ] the base list of tracked database field names
        def tracked_fields
          @tracked_fields ||= begin
            fields = history_trackable_options[:tracked_fields] + history_trackable_options[:tracked_dynamic]
            fields = fields - tracked_embedded_one - tracked_embedded_many
            fields
          end
        end

        # Retrieves the memoized list of reserved tracked fields, which are only included for certain actions.
        #
        # @return [ Array < String > ] the list of reserved database field names
        def reserved_tracked_fields
          @reserved_tracked_fields ||= ['_id', history_trackable_options[:version_field].to_s, "#{history_trackable_options[:modifier_field]}_id"]
        end

        # Whether or not the embedded relation should be tracked.
        #
        # @param [ String | Symbol ] relation The name of the embedded relation
        #
        # @return [ Boolean ] whether or not the embedded relation is tracked
        def tracked_relation?(relation)
          tracked_embedded_one?(relation) || tracked_embedded_many?(relation)
        end

        def tracked_embedded_one?(relation)
          tracked_embedded_one.include?(database_field_name(relation))
        end

        def tracked_embedded_one
          @tracked_embedded_one ||= begin
            reflect_on_all_associations(:embeds_one)
            .map(&:key)
            .select { |rel| history_trackable_options[:tracked_relations].include? rel }
          end
        end

        def tracked_embedded_many?(relation)
          tracked_embedded_many.include?(database_field_name(relation))
        end

        def tracked_embedded_many
          @tracked_embedded_many ||= begin
            reflect_on_all_associations(:embeds_many)
            .map(&:key)
            .select { |rel| history_trackable_options[:tracked_relations].include? rel }
          end
        end

        def history_trackable_options
          @history_trackable_options ||= Mongoid::History.trackable_class_options[collection_name.to_s.singularize.to_sym]
        end

        # Indicates whether there is an Embedded::One relation for the given embedded field.
        #
        # @param [ String | Symbol ] embed The name of the embedded field
        #
        # @return [ Boolean ] true if there is an Embedded::One relation for the given embedded field
        def embeds_one?(embed)
          relation_of(embed) == Mongoid::Relations::Embedded::One
        end

        # Indicates whether there is an Embedded::Many relation for the given embedded field.
        #
        # @param [ String | Symbol ] embed The name of the embedded field
        #
        # @return [ Boolean ] true if there is an Embedded::Many relation for the given embedded field
        def embeds_many?(embed)
          relation_of(embed) == Mongoid::Relations::Embedded::Many
        end

        # Retrieves the database representation of an embedded field name, in case the :store_as option is used.
        #
        # @param [ String | Symbol ] embed The name or alias of the embedded field
        #
        # @return [ String ] the database name of the embedded field
        def embedded_alias(embed)
          embedded_aliases[embed]
        end

        def clear_trackable_memoization
          @reserved_tracked_fields = nil
          @history_trackable_options = nil
          @tracked_fields = nil
          @tracked_embedded_one = nil
          @tracked_embedded_many = nil
        end

        protected

        # Retrieves the memoized hash of embedded aliases and their associated database representations.
        #
        # @return [ Hash < String, String > ] hash of embedded aliases (keys) to database representations (values)
        def embedded_aliases
          @embedded_aliases ||= relations.inject(HashWithIndifferentAccess.new) do |h, (k, v)|
            h[v[:store_as] || k] = k
            h
          end
        end

        def relation_of(embed)
          meta = reflect_on_association(embedded_alias(embed))
          meta ? meta.relation : nil
        end
      end
    end
  end
end
