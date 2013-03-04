module Mongoid::History
  module Tracker
    extend ActiveSupport::Concern

    included do
      include Mongoid::Document
      include Mongoid::Timestamps
      attr_writer :trackable

      field       :association_chain,       :type => Array,     :default => []
      field       :modified,                :type => Hash
      field       :original,                :type => Hash
      field       :version,                 :type => Integer
      field       :action,                  :type => String
      field       :scope,                   :type => String
      belongs_to  :modifier,                :class_name => Mongoid::History.modifier_class_name

      index(:scope => 1)
      index(:association_chain => 1)

      Mongoid::History.tracker_class_name = self.name.tableize.singularize.to_sym

      if defined?(ActionController) and defined?(ActionController::Base)
        ActionController::Base.class_eval do
          around_filter Mongoid::History::Sweeper.instance
        end
      end
    end

    def undo!(modifier)
      if action.to_sym == :destroy
        re_create
      elsif action.to_sym == :create
        re_destroy
      else
        trackable.update_attributes!(undo_attr(modifier))
      end
    end

    def redo!(modifier)
      if action.to_sym == :destroy
        re_destroy
      elsif action.to_sym == :create
        re_create
      else
        trackable.update_attributes!(redo_attr(modifier))
      end
    end

    def undo_attr(modifier)
      undo_hash = affected.easy_unmerge(modified)
      undo_hash.easy_merge!(original)
      modifier_field = trackable.history_trackable_options[:modifier_field]
      undo_hash[modifier_field] = modifier
      (modified.keys - undo_hash.keys).each do |k|
        undo_hash[k] = nil
      end
      undo_hash
    end

    def redo_attr(modifier)
      redo_hash = affected.easy_unmerge(original)
      redo_hash.easy_merge!(modified)
      modifier_field = trackable.history_trackable_options[:modifier_field]
      redo_hash[modifier_field] = modifier
      redo_hash
    end

    def trackable_root
      @trackable_root ||= trackable_parents_and_trackable.first
    end

    def trackable
      @trackable ||= trackable_parents_and_trackable.last
    end

    def trackable_parents
      @trackable_parents ||= trackable_parents_and_trackable[0, -1]
    end

    def trackable_parent
      @trackable_parent ||= trackable_parents_and_trackable[-2]
    end


    def affected
      @affected ||= (modified.keys | original.keys).inject({}){ |h,k| h[k] =
        trackable ? trackable.attributes[k] : modified[k]; h}
    end

private

    def re_create
      association_chain.length > 1 ? create_on_parent : create_standalone
    end

    def re_destroy
      trackable.destroy
    end

    def create_standalone
      class_name = association_chain.first["name"]
      restored = class_name.constantize.new(modified)
      restored.id = modified["_id"]
      restored.save!
    end

    def create_on_parent
      name = association_chain.last["name"]
      if embeds_one?(trackable_parent, name)
        trackable_parent.send("create_#{name}!", modified)
      elsif embeds_many?(trackable_parent, name)
         trackable_parent.send(name).create!(modified)
      else
        raise "This should never happen. Please report bug!"
      end
    end

    def trackable_parents_and_trackable
      @trackable_parents_and_trackable ||= traverse_association_chain
    end

    def relation_of(doc, name)
      meta = doc.reflect_on_association(name)
      meta ? meta.relation : nil
    end

    def embeds_one?(doc, name)
      relation_of(doc, name) == Mongoid::Relations::Embedded::One
    end

    def embeds_many?(doc, name)
      relation_of(doc, name) == Mongoid::Relations::Embedded::Many
    end

    def traverse_association_chain
      chain = association_chain.dup
      doc = nil
      documents = []

      begin
        node = chain.shift
        name = node['name']

        doc = if doc.nil?
          # root association. First element of the association chain
          klass = name.classify.constantize
          klass.where(:_id => node['id']).first
        elsif embeds_one?(doc, name)
          doc.send(name)
        elsif embeds_many?(doc, name)
          doc.send(name).where(:_id => node['id']).first
        else
          raise "This should never happen. Please report bug."
        end
        documents << doc
      end while( !chain.empty? )
      documents
    end

  end
end
