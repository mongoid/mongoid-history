module Mongoid::History
  module Tracker
    extend ActiveSupport::Concern

    included do
      include Mongoid::Document
      include Mongoid::Timestamps
      
      field       :association_chain,       :type => Array,     :default => []
      field       :modified,                :type => Hash
      field       :version,                 :type => Integer
      field       :scope,                   :type => String
      referenced_in :modifier,              :class_name => Mongoid::History.modifer_class_name

      Mongoid::History.tracker_class_name = self.name.tableize.singularize.to_sym
    end
    
    
    module ClassMethods
    end
    
    
    def undo!
      merge_changes(trackable, attributes_before_change)
      trackable.save!
    end
    
    def redo!
      merge_changes(trackable, attributes_after_change)
      trackable.save!
    end
    
    def merge_changes(model, attributes_to_merge)
      attributes_to_merge.each do |k, v|
        if model.attributes[k].is_a?(Array) && v.is_a?(Array)
          # Todo: This merge is wrong
          model.send "#{k}=", ( model.attributes[k] + v ).unique
        elsif model.attributes[k].is_a?(Hash) && v.is_a?(Hash)
          # Todo: when deep merging, directions matter...
          # consider undo and redo both senarios
          model.send "#{k}=", model.attributes[k].deep_merge(v)
        else
          model.send("#{k}=", v)
        end
      end
      model
    end
    
    def attributes_before_change
      @attributes_before_change ||= modified.inject({}) { |h, kv| k,v = kv; h[k] = v[0]; h }
    end

    def attributes_after_change
      @attributes_after_change ||= modified.inject({}) { |h, k, v| k,v = kv; h[k] = v[1]; h }
    end
    
    def trackable
      @trackable ||= trackable_parents_and_trackable.last
    end
    
    def trackable_parents
      @trackable_parents ||= trackable_parents_and_trackable[0, -1]
    end
    
    
private
    def trackable_parents_and_trackable
      @trackable_parents_and_trackable ||= triverse_association_chain
    end

    def triverse_association_chain
      chain = association_chain.dup
      doc = nil
      documents = []
      begin
        node = chain.shift
        name = node['name']
        col  = doc.nil? ? name.classify.constantize : doc.send(name.tableize)
        doc  = col.where(:_id => node['id']).first
        documents << doc
      end while( !chain.empty? )
      documents
    end
    
  end
end