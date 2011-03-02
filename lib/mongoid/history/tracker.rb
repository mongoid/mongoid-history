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

      Mongoid::History.tracker_class_name = self.name.tableize.singularize.to_sym
    end
    
    
    module ClassMethods
    end
    
    
    def trackable
      parents_and_master.last
    end
    
    def trackable_parents
      parents_and_master[0, -1]
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
        name = node[:name]
        col  = doc.nil? ? name.classify.constantize : doc.send(name)
        doc  = col.where(:id => node[:id]).first
        documents << doc
      end while( !chain.empty? )
      documents
    end
    
  end
end