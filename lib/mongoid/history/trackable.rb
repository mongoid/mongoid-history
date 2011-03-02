module Mongoid::History
  module Trackable
    extend ActiveSupport::Concern
    
    module ClassMethods
      def track_history(options={})
        model_name = self.name.tableize.singularize.to_sym
        default_options = {
          :on             =>  :all,
          :except         =>  [:created_at, :updated_at]
          :user_field     =>  :created_at,
          :version_field  =>  :version,
          :scope          =>  model_name,
          :track_create   =>  false
        }

        options = default_options.merge(options)
        
        # normalize except fields
        # manually ensure _id, id, version will not be tracked in history
        options[:except] = [options[:except]] unless options[:except].is_a? Array
        options[:except] << options[:version_field]
        options[:except] += [:_id, :id]
        options[:except] = [options[:except]].map(&:to_s).flatten.compact.unique
        options[:except].map(&:to_s)
        
        # normalize fields to track to either :all or an array of strings
        if options[:on] != :all
          options[:on] = [options[:on]] unless options[:on].is_a? Array
          options[:on] = [options[:on]].map(&:to_s).flatten.unique
        end
        
        
        include InstanceMethods
        extend SingletonMethods
        
        delegate :history_trackable_options, :to => 'self.class'
        
        define_callbacks :update, :before do |doc|
          doc.track_update
        end
        
        if options[:track_create]
          define_callbacks :create, :before do |doc|
            doc.track_create
          end
        end
        
        Mongoid::History.trackable_classes ||= []
        Mongoid::History.trackable_classes << self
        Mongoid::History.trackable_class_options ||= {}
        Mongoid::History.trackable_class_options[model_name] = options
      end
      
    end
    
    module InstanceMethods
      def history_tracks
        @history_tracks ||= Mongoid::History.tracker_class.where(:scope => history_trackable_options[:scope], :association_chain => triverse_association_chain)
      end
      
    private
      def should_track_update?
        !modified_attributes_for_update.blank?
      end
      
      def triverse_association_chain(node=self)
        list = node._parent ? triverse_all_parents(node._parent) : []
        list << { 'name' => node.class.name, 'id' => node.id }
        list
      end
      
      def modified_attributes_for_update
        @modified_attributes_for_update ||= (history_trackable_options[:on] == :all ? changes : changes.reject do |k, v|
          !history_trackable_options[:on].include?(k)}
        end.reject do |k, v|
          history_trackable_options[:except].include?(k)}
        end
      end
      
      def modified_attributes_for_create
        @modified_attributes_for_create ||= attributes.inject({}) do |h, k, v|
          h[k] = [[], v]
          h
        end.reject do |k, v|
          history_trackable_options[:except].include?(k)}
        end
      end

      def history_tracker_attributes
        @history_tracker_attributes ||= {
          :association_chain  => triverse_association_chain,
          :modified           => new_record? ? modified_attributes_for_create : modified_attributes_for_update,
          :version            => ( self.version || 0 ) + 1,
          :scope              => history_trackable_options[:scope],
          :modified_by        => send history_trackable_options[:user_field]
        }
      end
      
      def track_update
        return unless should_track_update?
        
        self.send("#{history_trackable_options[:version_field]}=", history_tracker_attributes[:version])
        Mongoid::History.tracker_class.create!(history_tracker_attributes)
      end
      
      def track_create
        self.send("#{history_trackable_options[:version_field]}=", history_tracker_attributes[:version])
        Mongoid::History.tracker_class.create!(history_tracker_attributes)
      end
      
    end
    
    module SingletonMethods
      def history_trackable_options
        @history_trackable_options ||= Mongoid::History.trackable_class_options[self.name.tableize.singularize.to_sym]
      end
    end
    
  end
end