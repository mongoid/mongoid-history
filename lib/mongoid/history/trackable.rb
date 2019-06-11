module Mongoid
  module History
    module Trackable
      extend ActiveSupport::Concern

      module ClassMethods
        def track_history(options = {})
          extend RelationMethods

          history_options = Mongoid::History::Options.new(self, options)

          field history_options.options[:version_field].to_sym, type: Integer

          unless history_options.options[:modifier_field].nil?
            belongs_to_modifier_options = { class_name: Mongoid::History.modifier_class_name }
            belongs_to_modifier_options[:inverse_of] = history_options.options[:modifier_field_inverse_of] if history_options.options.key?(:modifier_field_inverse_of)
            belongs_to_modifier_options[:optional] = true if history_options.options[:modifier_field_optional] && Mongoid::Compatibility::Version.mongoid6_or_newer?
            belongs_to history_options.options[:modifier_field].to_sym, belongs_to_modifier_options
          end

          include MyInstanceMethods
          extend SingletonMethods

          delegate :history_trackable_options, to: 'self.class'
          delegate :track_history?, to: 'self.class'

          callback_options = history_options.options.slice(:if, :unless)
          around_update :track_update, callback_options if history_options.options[:track_update]
          around_create :track_create, callback_options if history_options.options[:track_create]
          around_destroy :track_destroy, callback_options if history_options.options[:track_destroy]

          unless respond_to? :mongoid_history_options
            class_attribute :mongoid_history_options, instance_accessor: false
          end

          self.mongoid_history_options = history_options
        end

        def history_settings(options = {})
          options = Mongoid::History.default_settings.merge(options.symbolize_keys)
          options = options.slice(*Mongoid::History.default_settings.keys)
          options[:paranoia_field] = aliased_fields[options[:paranoia_field].to_s] || options[:paranoia_field].to_s
          Mongoid::History.trackable_settings ||= {}
          Mongoid::History.trackable_settings[name.to_sym] = options
        end

        def track_history?
          Mongoid::History.enabled? && Mongoid::History.store[track_history_flag] != false
        end

        def dynamic_enabled?
          Mongoid::Compatibility::Version.mongoid3? || (self < Mongoid::Attributes::Dynamic).present?
        end

        def disable_tracking(&_block)
          Mongoid::History.store[track_history_flag] = false
          yield
        ensure
          Mongoid::History.store[track_history_flag] = true
        end

        def track_history_flag
          "mongoid_history_#{name.underscore}_trackable_enabled".to_sym
        end

        def tracker_class
          klass = history_trackable_options[:tracker_class_name] || Mongoid::History.tracker_class_name
          klass.is_a?(Class) ? klass : klass.to_s.camelize.constantize
        end
      end

      module MyInstanceMethods
        def history_tracks
          @history_tracks ||= self.class.tracker_class.where(
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

        def _get_relation(name)
          send(self.class.relation_alias(name))
        end

        def _create_relation(name, value)
          send("create_#{self.class.relation_alias(name)}!", value)
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
              raise 'Invalid options, please specify (:from / :to) keys or :last key.'
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
            elsif Mongoid::Compatibility::Version.mongoid6_or_older?
              scope = relation_metadata.inverse_class_name.tableize.singularize.to_sym if relation_metadata.present? && scope == relation_metadata.as
            elsif Mongoid::Compatibility::Version.mongoid7_or_newer?
              scope = _association.inverse_class_name.tableize.singularize.to_sym if _association.present? && scope == _association.as
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
          # we're assured, through the object creation, it'll exist. Whereas we're not guaranteed
          # the child to parent (embedded_in, belongs_to) relation will be defined
          if node._parent
            meta = node._parent.relations.values.find do |relation|
              if Mongoid::Compatibility::Version.mongoid3?
                relation.class_name == node.metadata.class_name.to_s && relation.name == node.metadata.name
              elsif Mongoid::Compatibility::Version.mongoid6_or_older?
                relation.class_name == node.relation_metadata.class_name.to_s &&
                  relation.name == node.relation_metadata.name
              elsif Mongoid::Compatibility::Version.mongoid7_or_newer?
                relation.class_name == node._association.class_name.to_s &&
                  relation.name == node._association.name
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
          @modified_attributes_for_update ||= Mongoid::History::Attributes::Update.new(self).attributes
        end

        def modified_attributes_for_create
          @modified_attributes_for_create ||= Mongoid::History::Attributes::Create.new(self).attributes
        end

        def modified_attributes_for_destroy
          @modified_attributes_for_destroy ||= Mongoid::History::Attributes::Destroy.new(self).attributes
        end

        def history_tracker_attributes(action)
          return @history_tracker_attributes if @history_tracker_attributes

          modifier_field = history_trackable_options[:modifier_field]
          @history_tracker_attributes = {
            association_chain: traverse_association_chain,
            scope: related_scope
          }
          @history_tracker_attributes[:modifier] = send(modifier_field) if modifier_field

          original, modified = transform_changes(modified_attributes_for_action(action))

          @history_tracker_attributes[:original] = original
          @history_tracker_attributes[:modified] = modified
          @history_tracker_attributes
        end

        def track_create(&block)
          track_history_for_action(:create, &block)
        end

        def track_update(&block)
          track_history_for_action(:update, &block)
        end

        def track_destroy(&block)
          track_history_for_action(:destroy, &block) unless destroyed?
        end

        def clear_trackable_memoization
          @history_tracker_attributes = nil
          @modified_attributes_for_create = nil
          @modified_attributes_for_update = nil
          @history_tracks = nil
        end

        # Transform hash of pair of changes into an `original` and `modified` hash
        # Nested document keys (key name with dots) are expanded
        #
        # @param [Hash<Array>] changes
        #
        # @return [Array<Hash<?>,Hash<?>>] <description>
        def transform_changes(changes)
          original = {}
          modified = {}
          changes.each_pair do |k, modification_pair|
            o, m = modification_pair
            original.deep_merge!(expand_nested_document_key_value(k, o)) unless o.nil?
            modified.deep_merge!(expand_nested_document_key_value(k, m)) unless m.nil?
          end

          [original, modified]
        end

        # Handle nested document tracking of changes
        #
        # @example
        #
        #   expand_nested_document_key('embedded.document.changed_field', 'old'])
        #   #=> { 'embedded' => {'document' => { 'changed_field' => 'old' }}}
        #
        # @param [String] document_key key with dots
        # @param [?] value
        #
        # @return [Hash<String, ?>]
        def expand_nested_document_key_value(document_key, value)
          expanded_key = value
          document_key.to_s.split('.').reverse.each do |key|
            expanded_key = { key => expanded_key }
          end
          expanded_key
        end

        def increment_current_version
          current_version = (send(history_trackable_options[:version_field]) || 0) + 1
          send("#{history_trackable_options[:version_field]}=", current_version)
          current_version
        end

        protected

        def track_history_for_action?(action)
          track_history? && !(action.to_sym == :update && modified_attributes_for_update.blank?)
        end

        def track_history_for_action(action)
          if track_history_for_action?(action)
            current_version = increment_current_version
            last_track = self.class.tracker_class.create!(
              history_tracker_attributes(action.to_sym)
              .merge(version: current_version, action: action.to_s, trackable: self)
            )
          end

          clear_trackable_memoization

          begin
            yield
          rescue => e
            if track_history_for_action?(action)
              send("#{history_trackable_options[:version_field]}=", current_version - 1)
              last_track.destroy
            end
            raise e
          end
        end
      end

      module RelationMethods
        # Returns a relation class for the given field.
        #
        # @param [ String | Symbol ] field The name of the field.
        #
        # @return [ nil | Constant ] Class being related.
        def relation_class_of(field)
          meta = meta_of(field)
          return meta.class_name.constantize if meta
        end

        # Indicates whether there is an Embedded::One relation for the given embedded field.
        #
        # @param [ String | Symbol ] embed The name of the embedded field.
        #
        # @return [ Boolean ] true if there is an Embedded::One relation for the given embedded field.
        def embeds_one?(field)
          relation_of(field) == if Mongoid::Compatibility::Version.mongoid7_or_newer?
                                  Mongoid::Association::Embedded::EmbedsOne::Proxy
                                else
                                  Mongoid::Relations::Embedded::One
                                end
        end

        # Indicates whether there is an Embedded::Many relation for the given embedded field.
        #
        # @param [ String | Symbol ] field The name of the embedded field.
        #
        # @return [ Boolean ] true if there is an Embedded::Many relation for the given embedded field.
        def embeds_many?(field)
          relation_of(field) == if Mongoid::Compatibility::Version.mongoid7_or_newer?
                                  Mongoid::Association::Embedded::EmbedsMany::Proxy
                                else
                                  Mongoid::Relations::Embedded::Many
                                end
        end

        # Retrieves the database representation of an embedded field name, in case the :store_as option is used.
        #
        # @param [ String | Symbol ] embed The name or alias of the embedded field.
        #
        # @return [ String ] The database name of the embedded field.
        def relation_alias(embed)
          relation_aliases[embed]
        end

        protected

        # Return the reflected metadata for a relation.
        #
        # @param [ String ] field The database field name for a relation.
        #
        # @return [ nil | Mongoid::Relations::Metadata ]
        def meta_of(field)
          @meta_of ||= {}
          return @meta_of[field] if @meta_of.key?(field)
          @meta_of[field] = reflect_on_association(relation_alias(field))
        end

        # Returns a relation for the given field.
        #
        # @param [ String | Symbol ] field The name of the field.
        #
        # @return [ nil | Constant ] Type of relation.
        def relation_of(field)
          meta = meta_of(field)
          meta ? meta.relation : nil
        end

        # Retrieves the memoized hash of embedded aliases and their associated database representations.
        #
        # @return [ Hash < String, String > ] hash of embedded aliases (keys) to database representations (values)
        def relation_aliases
          @relation_aliases ||= relations.inject(HashWithIndifferentAccess.new) do |h, (k, v)|
            store_as = Mongoid::Compatibility::Version.mongoid7_or_newer? ? v.store_as : v[:store_as]
            h[store_as || k] = k
            h
          end
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
          dynamic_enabled? &&
            !fields.keys.include?(database_field_name(field)) &&
            !embedded_relations.map { |_, v| v.key }.include?(database_field_name(field))
        end

        def field_format(field)
          field_formats[database_field_name(field)]
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

        # Retrieves the memoized base list of tracked fields, excluding reserved fields.
        #
        # @return [ Array < String > ] the base list of tracked database field names
        def tracked_fields
          @tracked_fields ||= history_trackable_options[:fields] + history_trackable_options[:dynamic]
        end

        # Retrieves the memoized list of reserved tracked fields, which are only included for certain actions.
        #
        # @return [ Array < String > ] the list of reserved database field names
        def reserved_tracked_fields
          @reserved_tracked_fields ||= begin
                                         fields = ['_id', history_trackable_options[:version_field].to_s]
                                         modifier_field = history_trackable_options[:modifier_field]
                                         fields << "#{modifier_field}_id" if modifier_field
                                         fields
                                       end
        end

        def field_formats
          @field_formats ||= history_trackable_options[:format]
        end

        # Whether or not the relation should be tracked.
        #
        # @param [ String | Symbol ] relation The name of the relation
        #
        # @return [ Boolean ] whether or not the relation is tracked
        def tracked_relation?(relation)
          tracked_embeds_one?(relation) || tracked_embeds_many?(relation)
        end

        # Whether or not the embeds_one relation should be tracked.
        #
        # @param [ String | Symbol ] relation The name of the embeds_one relation
        #
        # @return [ Boolean ] whether or not the embeds_one relation is tracked
        def tracked_embeds_one?(relation)
          tracked_embeds_one.include?(database_field_name(relation))
        end

        # Retrieves the memoized list of tracked embeds_one relations
        #
        # @return [ Array < String > ] the list of tracked embeds_one relations
        def tracked_embeds_one
          @tracked_embeds_one ||= begin
            reflect_on_all_associations(:embeds_one)
              .map(&:key)
              .select { |rel| history_trackable_options[:relations][:embeds_one].include? rel }
          end
        end

        def tracked_embeds_one_attributes(relation)
          history_trackable_options[:relations][:embeds_one][database_field_name(relation)]
        end

        # Whether or not the embeds_many relation should be tracked.
        #
        # @param [ String | Symbol ] relation The name of the embeds_many relation
        #
        # @return [ Boolean ] whether or not the embeds_many relation is tracked
        def tracked_embeds_many?(relation)
          tracked_embeds_many.include?(database_field_name(relation))
        end

        # Retrieves the memoized list of tracked embeds_many relations
        #
        # @return [ Array < String > ] the list of tracked embeds_many relations
        def tracked_embeds_many
          @tracked_embeds_many ||= begin
            reflect_on_all_associations(:embeds_many)
              .map(&:key)
              .select { |rel| history_trackable_options[:relations][:embeds_many].include? rel }
          end
        end

        def tracked_embeds_many_attributes(relation)
          history_trackable_options[:relations][:embeds_many][database_field_name(relation)]
        end

        def trackable_scope
          collection_name.to_s.singularize.to_sym
        end

        def history_trackable_options
          @history_trackable_options ||= mongoid_history_options.prepared
        end

        def clear_trackable_memoization
          @reserved_tracked_fields = nil
          @history_trackable_options = nil
          @trackable_settings = nil
          @tracked_fields = nil
          @tracked_embeds_one = nil
          @tracked_embeds_many = nil
          @obfuscated_fields = nil
        end
      end
    end
  end
end
