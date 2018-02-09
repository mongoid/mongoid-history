module Mongoid
  module History
    module Attributes
      class Update < ::Mongoid::History::Attributes::Base
        def attributes
          @attributes = {}
          changes.each do |k, v|
            if trackable_class.tracked_embeds_one?(k)
              insert_embeds_one_changes(k, v)
            elsif trackable_class.tracked_embeds_many?(k)
              insert_embeds_many_changes(k, v)
            elsif trackable_class.tracked?(k, :update)
              @attributes[k] = format_field(k, v) unless v.all?(&:blank?)
            end
          end
          insert_embeds_one_changes_on_child if trackable_class.tracked_embeds_one.present? && changes.empty?
          @attributes
        end

        private

        def insert_embeds_one_changes(relation, value)
          relation = trackable_class.database_field_name(relation)
          relation_class = trackable_class.relation_class_of(relation)
          paranoia_field = Mongoid::History.trackable_class_settings(relation_class)[:paranoia_field]
          original_value = value[0][paranoia_field].present? ? {} : format_embeds_one_relation(relation, value[0])
          modified_value = value[1][paranoia_field].present? ? {} : format_embeds_one_relation(relation, value[1])
          return if original_value == modified_value
          @attributes[relation] = [original_value, modified_value]
        end

        def insert_embeds_one_changes_on_child
          trackable_class.tracked_embeds_one.each do |rel|
            rel_class = trackable_class.embeds_one_class(rel)
            paranoia_field = Mongoid::History.trackable_class_settings(rel_class)[:paranoia_field]
            paranoia_field = rel_class.aliased_fields.key(paranoia_field) || paranoia_field
            rel = aliased_fields.key(rel) || rel
            obj = trackable.send(rel)
            next if !obj || (obj.respond_to?(paranoia_field) && obj.public_send(paranoia_field).present?)
            @attributes[rel] = {}
            obj.changes.each do |k, v|
              @attributes[rel] = [{ k => v.first }, { k => v.last }]
            end
          end
          @attributes
        end

        def insert_embeds_many_changes(relation, value)
          relation = trackable_class.database_field_name(relation)
          relation_class = trackable_class.relation_class_of(relation)
          paranoia_field = Mongoid::History.trackable_class_settings(relation_class)[:paranoia_field]
          original_value = value[0].reject { |rel| rel[paranoia_field].present? }
                                   .map { |v_attrs| format_embeds_many_relation(relation, v_attrs) }
          modified_value = value[1].reject { |rel| rel[paranoia_field].present? }
                                   .map { |v_attrs| format_embeds_many_relation(relation, v_attrs) }
          return if original_value == modified_value
          @attributes[relation] = [original_value, modified_value]
        end
      end
    end
  end
end
