module Mongoid::History
  module Trackable
    extend ActiveSupport::Concern
    
    module ClassMethods
      def track_history(options={})
        model_name = self.name.tableize.singularize.to_sym
        default_options = {
          :on             =>  :all,
          :except         =>  [:created_at, :updated_at],
          :modifier_field =>  :modifier,
          :version_field  =>  :version,
          :scope          =>  model_name,
          :track_create   =>  false
        }

        options = default_options.merge(options)
        
        # normalize except fields
        # manually ensure _id, id, version will not be tracked in history
        options[:except] = [options[:except]] unless options[:except].is_a? Array
        options[:except] << options[:version_field]
        options[:except] << "#{options[:modifier_field]}_id".to_sym
        options[:except] += [:_id, :id]
        options[:except] = options[:except].map(&:to_s).flatten.compact.uniq
        options[:except].map(&:to_s)
        
        # normalize fields to track to either :all or an array of strings
        if options[:on] != :all
          options[:on] = [options[:on]] unless options[:on].is_a? Array
          options[:on] = options[:on].map(&:to_s).flatten.uniq
        end
        
        field options[:version_field].to_sym, :type => Integer
        referenced_in options[:modifier_field].to_sym, :class_name => Mongoid::History.modifer_class_name
        
        include InstanceMethods
        extend SingletonMethods
        
        delegate :history_trackable_options, :to => 'self.class'
        delegate :track_history?, :to => 'self.class'

        before_update :track_update
        before_create :track_create if options[:track_create]

        
        Mongoid::History.trackable_classes ||= []
        Mongoid::History.trackable_classes << self
        Mongoid::History.trackable_class_options ||= {}
        Mongoid::History.trackable_class_options[model_name] = options
        Thread.current[:mongoid_history_trackable_enabled] = true
      end
      
      def track_history?
        !!Thread.current[:mongoid_history_trackable_enabled]
      end
      
      def disable_tracking(&block)
        Thread.current[:mongoid_history_trackable_enabled] = false
        yield
        Thread.current[:mongoid_history_trackable_enabled] = true
      end
    end
    
    module InstanceMethods
      def history_tracks
        @history_tracks ||= Mongoid::History.tracker_class.where(:scope => history_trackable_options[:scope], :association_chain => triverse_association_chain)
      end
      
    private
      def should_track_update?
        track_history? && !modified_attributes_for_update.blank?
      end
      
      def triverse_association_chain(node=self)
        list = node._parent ? triverse_association_chain(node._parent) : []
        list << { 'name' => node.class.name, 'id' => node.id }
        list
      end
      
      def modified_attributes_for_update
        @modified_attributes_for_update ||= if history_trackable_options[:on] == :all
          changes
        else
          changes.reject do |k, v|
            !history_trackable_options[:on].include?(k)
          end.reject do |k, v|
            history_trackable_options[:except].include?(k)
          end
        end
      end
      
      def modified_attributes_for_create
        @modified_attributes_for_create ||= attributes.inject({}) do |h, pair|
          k,v =  pair
          h[k] = [nil, v]
          h
        end.reject do |k, v|
          history_trackable_options[:except].include?(k)
        end
      end

      def history_tracker_attributes
        return @history_tracker_attributes if @history_tracker_attributes
        
        @history_tracker_attributes = {
          :association_chain  => triverse_association_chain,
          :scope              => history_trackable_options[:scope],
          :modifier        => send(history_trackable_options[:modifier_field])
        }
        
        original, modified = transform_changes((new_record? ? modified_attributes_for_create : modified_attributes_for_update))
        @history_tracker_attributes[:original] = original
        @history_tracker_attributes[:modified] = modified
        @history_tracker_attributes
      end
      
      def track_update
        return unless should_track_update?
        current_version = (self.send(history_trackable_options[:version_field]) || 0 ) + 1
        self.send("#{history_trackable_options[:version_field]}=", current_version)
        Mongoid::History.tracker_class.create!(history_tracker_attributes.merge(:version => current_version))
        clear_memoization
      end
      
      def track_create
        return unless track_history?
        current_version = (self.send(history_trackable_options[:version_field]) || 0 ) + 1
        self.send("#{history_trackable_options[:version_field]}=", current_version)
        Mongoid::History.tracker_class.create!(history_tracker_attributes.merge(:version => current_version))
        clear_memoization
      end
      
      def clear_memoization
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
          original[k] = o if o
          modified[k] = m if m
        end
        
        return original.easy_diff modified
      end
      
    end
    
    module SingletonMethods
      def history_trackable_options
        @history_trackable_options ||= Mongoid::History.trackable_class_options[self.name.tableize.singularize.to_sym]
      end
    end
    
  end
end