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
      localize_keys(undo_hash)
    end

    def redo_attr(modifier)
      redo_hash = affected.easy_unmerge(original)
      redo_hash.easy_merge!(modified)
      modifier_field = trackable.history_trackable_options[:modifier_field]
      redo_hash[modifier_field] = modifier
      localize_keys(redo_hash)
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

    # Outputs a :from, :to hash for each affected field.
    #
    # @result Hash a change set in the format:
    #   { field_1: {to: new_val}, field_2: {from: old_val, to: new_val} }
    def tracked_changes
      @tracked_changes ||= (modified.keys | original.keys).inject(HashWithIndifferentAccess.new) do |h,k|
        h[k] = {from: original[k], to: modified[k]}.delete_if{|k,v| v.nil?}
        h
      end.delete_if{|k,v| v.blank?}
    end

    # Outputs summary of edit actions performed: :add, :modify, :remove, or :array.
    # Does deep comparison of arrays. Useful for creating human-readable representations
    # of the history tracker. Considers changing a value to 'blank' to be a removal.
    #
    # @result Hash a change set in the format:
    #   { add: { field_1: new_val, ... },
    #     modify: { field_2: {from: old_val, to: new_val}, ... },
    #     remove: { field_3: old_val },
    #     array: { field_4: {add: ['foo', 'bar'], remove: ['baz']} } }
    def tracked_edits
      @tracked_edits ||= tracked_changes.inject(HashWithIndifferentAccess.new) do |h,(k,v)|
        return h if v[:from].blank? && v[:to].blank?
        if v[:from].blank?
          h[:add] ||={}
          h[:add][k] = v[:to]
        elsif v[:to].blank?
          h[:remove] ||={}
          h[:remove][k] = v[:from]
        else
          if v[:from].is_a?(Array) && v[:to].is_a?(Array)
            h[:array] ||={}
            old_values = v[:from] - v[:to]
            new_values = v[:to] - v[:from]
            h[:array][k] = {add: new_values, remove: old_values}.delete_if{|k,v| v.blank?}
          else
            h[:modify] ||={}
            h[:modify][k] = v
          end
        end
        h
      end
    end

    # Similar to changes, but only includes the new (modified) value for each
    # affected field. Included for legacy compatibility.
    #
    # @deprecated
    #
    # @result Hash a change set in the format:
    #   { field_1: new_val, field_2: new_val }
    def affected
      @affected ||= tracked_changes.inject(HashWithIndifferentAccess.new){|h,(k,v)| h[k]=v[:to]; h}
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
      restored = class_name.constantize.new(localize_keys(modified))
      restored.id = modified["_id"]
      restored.save!
    end

    def create_on_parent
      name = association_chain.last["name"]
      if embeds_one?(trackable_parent, name)
        trackable_parent.send("create_#{name}!", localize_keys(modified))
      elsif embeds_many?(trackable_parent, name)
         trackable_parent.send(name).create!(localize_keys(modified))
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

    def localize_keys(hash)
      klass = association_chain.first["name"].constantize
      klass.localized_fields.keys.each do |name|
        hash["#{name}_translations"] = hash.delete(name) if hash[name].present?
      end if klass.respond_to?(:localized_fields)
      hash
    end

  end
end
