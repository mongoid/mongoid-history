module Mongoid
  module History
    module Attributes
      class Update < ::Mongoid::History::Attributes::Base
        # @example
        #
        #   {
        #     'foo' => ['foo_before_changes', 'foo_after_changes']
        #     'nested_bar' => {
        #       'baz' => ['nested_bar_baz_before_changes', 'nested_bar_baz_after_changes']
        #     }
        #   }
        #
        # @return [Hash<String, ?>] Hash of changes
        #   ? can be either a pair or a hash for embedded documents
        def attributes
          require 'byebug'
          byebug
          changes_from_parent.deep_merge(changes_from_children)
        end

        private

        def changes_from_parent
          parent_changes = {}
          changes.each do |k, v|
            change_value = begin
              if trackable_class.tracked_embeds_one?(k)
                embeds_one_changes_from_parent(k, v)
              elsif trackable_class.tracked_embeds_many?(k)
                embeds_many_changes_from_parent(k, v)
              elsif trackable_class.tracked?(k, :update)
                { k => format_field(k, v) } unless v.all?(&:blank?)
              end
            end
            parent_changes.merge!(change_value) if change_value.present?
          end
          parent_changes
        end

        def changes_from_children
          embeds_one_changes_from_embedded_documents
        end

        # @return [Hash<String, Array<?,?>] changes of embeds_ones from embedded documents
        def embeds_one_changes_from_embedded_documents
          embedded_doc_changes = {}
          trackable_class.tracked_embeds_one.each do |rel|
            rel_class = trackable_class.relation_class_of(rel)
            paranoia_field = Mongoid::History.trackable_class_settings(rel_class)[:paranoia_field]
            paranoia_field = rel_class.aliased_fields.key(paranoia_field) || paranoia_field
            rel = aliased_fields.key(rel) || rel
            obj = trackable.send(rel)
            next if !obj || (obj.respond_to?(paranoia_field) && obj.public_send(paranoia_field).present?)
            embedded_doc_field_changes = obj.changes.map do |k,v|
              [{ k => v.first }, { k => v.last }]
            end
            embedded_doc_changes[rel] = embedded_doc_field_changes if embedded_doc_field_changes.any?
          end
          embedded_doc_changes
        end

        # @param [String] relation <description>
        # @param [String] value <description>
        #
        # @return [Hash<String, Array<(?,?)>>]
        def embeds_one_changes_from_parent(relation, value)
          relation = trackable_class.database_field_name(relation)
          relation_class = trackable_class.relation_class_of(relation)
          paranoia_field = Mongoid::History.trackable_class_settings(relation_class)[:paranoia_field]
          original_value = value[0][paranoia_field].present? ? {} : format_embeds_one_relation(relation, value[0])
          modified_value = value[1][paranoia_field].present? ? {} : format_embeds_one_relation(relation, value[1])
          return if original_value == modified_value
          [original_value, modified_value]
          byebug
          { relation => [original_value, modified_value] }
        end

        # @param [String] relation <description>
        # @param [String] value <description>
        #
        # @return [Hash<Array<(?,?)>>]
        def embeds_many_changes_from_parent(relation, value)
          relation = trackable_class.database_field_name(relation)
          relation_class = trackable_class.relation_class_of(relation)
          paranoia_field = Mongoid::History.trackable_class_settings(relation_class)[:paranoia_field]
          original_value = value[0].reject { |rel| rel[paranoia_field].present? }
                                   .map { |v_attrs| format_embeds_many_relation(relation, v_attrs) }
          modified_value = value[1].reject { |rel| rel[paranoia_field].present? }
                                   .map { |v_attrs| format_embeds_many_relation(relation, v_attrs) }
          return if original_value == modified_value
          { relation => [original_value, modified_value] }
        end
      end
    end
  end
end
