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
    end

    def undo!(modifier)
      if action.to_sym == :destroy
        re_create
      elsif action.to_sym == :create
        re_destroy
      else
        trackable.assign_attributes!(undo_attr(modifier))
        trackable.save!
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

    # Outputs a :from, :to hash for each affected field. Intentionally excludes fields
    # which are not tracked, even if there are tracked values for such fields
    # present in the database.
    #
    # @return [ HashWithIndifferentAccess ] a change set in the format:
    #   { field_1: {to: new_val}, field_2: {from: old_val, to: new_val} }
    def tracked_changes
      @tracked_changes ||= (modified.keys | original.keys).inject(HashWithIndifferentAccess.new) do |h,k|
        h[k] = {from: original[k], to: modified[k]}.delete_if{|k,v| v.nil?}
        h
      end.delete_if{|k,v| v.blank? || !trackable_parent_class.tracked_field?(k)}
    end

    # Outputs summary of edit actions performed: :add, :modify, :remove, or :array.
    # Does deep comparison of arrays. Useful for creating human-readable representations
    # of the history tracker. Considers changing a value to 'blank' to be a removal.
    #
    # @return [ HashWithIndifferentAccess ] a change set in the format:
    #   { add: { field_1: new_val, ... },
    #     modify: { field_2: {from: old_val, to: new_val}, ... },
    #     remove: { field_3: old_val },
    #     array: { field_4: {add: ['foo', 'bar'], remove: ['baz']} } }
    def tracked_edits
      @tracked_edits ||= tracked_changes.inject(HashWithIndifferentAccess.new) do |h,(k,v)|
        unless v[:from].blank? && v[:to].blank?
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
        end
        h
      end
    end

    # Similar to #tracked_changes, but contains only a single value for each
    # affected field:
    #   - :create and :update return the modified values
    #   - :destroy returns original values
    # Included for legacy compatibility.
    #
    # @deprecated
    #
    # @return [ HashWithIndifferentAccess ] a change set in the format:
    #   { field_1: value, field_2: value }
    def affected
      target = action.to_sym == :destroy ? :from : :to
      @affected ||= tracked_changes.inject(HashWithIndifferentAccess.new){|h,(k,v)| h[k] = v[target]; h}
    end

    # Returns the class of the trackable, irrespective of whether the trackable object
    # has been destroyed.
    #
    # @return [ Class ] the class of the trackable
    def trackable_parent_class
      association_chain.first["name"].constantize
    end

    private

    def re_create
      association_chain.length > 1 ? create_on_parent : create_standalone
    end

    def re_destroy
      trackable.destroy
    end

    def create_standalone
      restored = trackable_parent_class.new(localize_keys(original))
      restored.id = original["_id"]
      restored.save!
    end

    def create_on_parent
      name = association_chain.last["name"]
      if trackable_parent.class.embeds_one?(name)
        trackable_parent.create_embedded(name, localize_keys(original))
      elsif trackable_parent.class.embeds_many?(name)
        trackable_parent.get_embedded(name).create!(localize_keys(original))
      else
        raise "This should never happen. Please report bug!"
      end
    end

    def trackable_parents_and_trackable
      @trackable_parents_and_trackable ||= traverse_association_chain
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
        elsif doc.class.embeds_one?(name)
          doc.get_embedded(name)
        elsif doc.class.embeds_many?(name)
          doc.get_embedded(name).where(:_id => node['id']).first
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
