module Mongoid::History
  module Trackable
    extend ActiveSupport::Concern

    module ClassMethods
      def track_history(options={})
        scope_name = self.collection_name.to_s.singularize.to_sym
        default_options = {
          :on             =>  :all,
          :except         =>  [:created_at, :updated_at],
          :modifier_field =>  :modifier,
          :version_field  =>  :version,
          :changes_method =>  :changes,
          :scope          =>  scope_name,
          :track_create   =>  false,
          :track_update   =>  true,
          :track_destroy  =>  false,
        }

        options = default_options.merge(options)

        # normalize :except fields to an array of database field strings
        options[:except] = [options[:except]] unless options[:except].is_a? Array
        options[:except] = options[:except].map{|field| database_field_name(field)}.compact.uniq

        # normalize :on fields to either :all or an array of database field strings
        if options[:on] != :all
          options[:on] = [options[:on]] unless options[:on].is_a? Array
          options[:on] = options[:on].map{|field| database_field_name(field)}.compact.uniq
        end

        field options[:version_field].to_sym, :type => Integer

        belongs_to_modifier_options = { :class_name => Mongoid::History.modifier_class_name }
        belongs_to_modifier_options[:inverse_of] = options[:modifier_field_inverse_of] if options.has_key?(:modifier_field_inverse_of)
        belongs_to options[:modifier_field].to_sym, belongs_to_modifier_options

        include MyInstanceMethods
        extend SingletonMethods

        delegate :history_trackable_options, :to => 'self.class'
        delegate :track_history?, :to => 'self.class'

        before_update :track_update if options[:track_update]
        before_create :track_create if options[:track_create]
        before_destroy :track_destroy if options[:track_destroy]

        Mongoid::History.trackable_class_options ||= {}
        Mongoid::History.trackable_class_options[scope_name] = options
      end

      def track_history?
        enabled = Thread.current[track_history_flag]
        Mongoid::History.enabled? && (enabled.nil? ? true : enabled)
      end

      def disable_tracking(&block)
        begin
          Thread.current[track_history_flag] = false
          yield
        ensure
          Thread.current[track_history_flag] = true
        end
      end

      def track_history_flag
        "mongoid_history_#{self.name.underscore}_trackable_enabled".to_sym
      end
    end

    module MyInstanceMethods
      def history_tracks
        @history_tracks ||= Mongoid::History.tracker_class.where(:scope => history_trackable_options[:scope], :association_chain => association_hash)
      end

      #  undo :from => 1, :to => 5
      #  undo 4
      #  undo :last => 10
      def undo!(modifier, options_or_version=nil)
        versions = get_versions_criteria(options_or_version).to_a
        versions.sort!{|v1, v2| v2.version <=> v1.version}

        versions.each do |v|
          self.attributes = v.undo_attr(modifier)
        end
        save!
      end

      def redo!(modifier, options_or_version=nil)
        versions = get_versions_criteria(options_or_version).to_a
        versions.sort!{|v1, v2| v1.version <=> v2.version}

        versions.each do |v|
          redo_attr = v.redo_attr(modifier)
          self.attributes = redo_attr
        end
        save!
      end

      def get_embedded(name)
        self.send(self.class.embedded_alias(name))
      end

      def create_embedded(name, value)
        self.send("create_#{self.class.embedded_alias(name)}!", value)
      end

    private
      def get_versions_criteria(options_or_version)
        if options_or_version.is_a? Hash
          options = options_or_version
          if options[:from] && options[:to]
            lower = options[:from] >= options[:to] ? options[:to] : options[:from]
            upper = options[:from] <  options[:to] ? options[:to] : options[:from]
            versions = history_tracks.where( :version.in => (lower .. upper).to_a )
          elsif options[:last]
            versions = history_tracks.limit( options[:last] )
          else
            raise "Invalid options, please specify (:from / :to) keys or :last key."
          end
        else
          options_or_version = options_or_version.to_a if options_or_version.is_a?(Range)
          version_field_name = history_trackable_options[:version_field]
          version = options_or_version || self.attributes[version_field_name] || self.attributes[version_field_name.to_s]
          version = [ version ].flatten
          versions = history_tracks.where(:version.in => version)
        end
        versions.desc(:version)
      end

      def traverse_association_chain(node=self)
        list = node._parent ? traverse_association_chain(node._parent) : []
        list << association_hash(node)
        list
      end

      def association_hash(node=self)

        # We prefer to look up associations through the parent record because
        # we're assured, through the object creation, it'll exist. Whereas we're not guarenteed
        # the child to parent (embedded_in, belongs_to) relation will be defined
        if node._parent
          meta = node._parent.relations.values.select do |relation|
            relation.class_name == node.metadata.class_name.to_s
          end.first
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
        @modified_attributes_for_update ||= self.send(history_trackable_options[:changes_method]).select{|k, v| self.class.tracked_field?(k, :update)}
      end

      def modified_attributes_for_create
        @modified_attributes_for_create ||= attributes.inject({}) do |h,(k,v)|
          h[k] = [nil, v]
          h
        end.select{|k, v| self.class.tracked_field?(k, :create)}
      end

      def modified_attributes_for_destroy
        @modified_attributes_for_destroy ||= attributes.inject({}) do |h,(k,v)|
          h[k] = [v, nil]
          h
        end.select{|k, v| self.class.tracked_field?(k, :destroy)}
      end

      def history_tracker_attributes(action)
        return @history_tracker_attributes if @history_tracker_attributes

        @history_tracker_attributes = {
          :association_chain  => traverse_association_chain,
          :scope              => history_trackable_options[:scope],
          :modifier           => send(history_trackable_options[:modifier_field])
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
        @history_tracker_attributes =  nil
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

        [ original, modified ]
      end

      protected

      def track_history_for_action?(action)
        track_history? && !(action.to_sym == :update && modified_attributes_for_update.blank?)
      end

      def track_history_for_action(action)
        if track_history_for_action?(action)
          current_version = (self.send(history_trackable_options[:version_field]) || 0 ) + 1
          self.send("#{history_trackable_options[:version_field]}=", current_version)
          Mongoid::History.tracker_class.create!(history_tracker_attributes(action.to_sym).merge(version: current_version, action: action.to_s, trackable: self))
        end
        clear_trackable_memoization
      end
    end

    module SingletonMethods

      # Whether or not the field should be tracked.
      #
      # @param [ String | Symbol ] field The name or alias of the field
      # @param [ String | Symbol ] action The optional action name (:create, :update, or :destroy)
      #
      # @return [ Boolean ] whether or not the field is tracked for the given action
      def tracked_field?(field, action = :update)
        tracked_fields_for_action(action).include? database_field_name(field)
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
        @tracked_fields ||= self.fields.keys.select do |field|
          h = history_trackable_options
          (h[:on]==:all || h[:on].include?(field)) && !h[:except].include?(field)
        end - reserved_tracked_fields
      end

      # Retrieves the memoized list of reserved tracked fields, which are only included for certain actions.
      #
      # @return [ Array < String > ] the list of reserved database field names
      def reserved_tracked_fields
        @reserved_tracked_fields ||= ["_id", history_trackable_options[:version_field].to_s, "#{history_trackable_options[:modifier_field]}_id"]
      end

      def history_trackable_options
        @history_trackable_options ||= Mongoid::History.trackable_class_options[self.collection_name.to_s.singularize.to_sym]
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

      protected

      # Retrieves the memoized hash of embedded aliases and their associated database representations.
      #
      # @return [ Hash < String, String > ] hash of embedded aliases (keys) to database representations (values)
      def embedded_aliases
        @embedded_aliases ||= relations.inject(HashWithIndifferentAccess.new) do |h,(k,v)|
          h[v[:store_as]||k]=k; h
        end
      end

      def relation_of(embed)
        meta = reflect_on_association(embedded_alias(embed))
        meta ? meta.relation : nil
      end
    end
  end
end
