module Mongoid
  module History
    module Attributes
      class Update < ::Mongoid::History::Attributes::Base
        # @example when both an attribute `foo` and a child's attribute `nested_bar.baz` are changed
        #
        #   {
        #     'foo' => ['foo_before_changes', 'foo_after_changes']
        #     'nested_bar.baz' => ['nested_bar_baz_before_changes', 'nested_bar_baz_after_changes']
        #     }
        #   }
        #
        # @return [Hash<String, Array<(?,?)>>] Hash of changes
        def attributes
          changes_from_parent.deep_merge(changes_from_children)
        end

        private

        def changes_from_parent
          track_blank_changes = trackable_class.history_trackable_options[:track_blank_changes]
          parent_changes = {}
          changes.each do |k, v|
            change_value = begin
              if trackable_class.tracked_embeds_one?(k)
                embeds_one_changes_from_parent(k, v)
              elsif trackable_class.tracked_embeds_many?(k)
                embeds_many_changes_from_parent(k, v)
              elsif trackable_class.tracked?(k, :update)
                { k => format_field(k, v) } unless !track_blank_changes && v.all?(&:blank?)
              end
            end
            parent_changes.merge!(change_value) if change_value.present?
          end
          parent_changes
        end

        def changes_from_children
          embeds_one_changes_from_embedded_documents
        end

        # Retrieve the list of changes applied directly to the nested documents
        #
        # @example when a child's name is changed from "todd" to "mario"
        #
        #   child = Child.new(name: 'todd')
        #   Parent.create(child: child)
        #   child.name = "Mario"
        #
        #   embeds_one_changes_from_embedded_documents # when called from "Parent"
        #   # => { "child.name"=>["todd", "mario"] }
        #
        # @return [Hash<String, Array<(?,?)>] changes of embeds_ones from embedded documents
        def embeds_one_changes_from_embedded_documents
          embedded_doc_changes = {}
          trackable_class.tracked_embeds_one.each do |rel|
            rel_class = trackable_class.relation_class_of(rel)
            paranoia_field = Mongoid::History.trackable_class_settings(rel_class)[:paranoia_field]
            paranoia_field = rel_class.aliased_fields.key(paranoia_field) || paranoia_field
            rel = aliased_fields.key(rel) || rel
            obj = trackable.send(rel)
            next if !obj || (obj.respond_to?(paranoia_field) && obj.public_send(paranoia_field).present?)

            obj.changes.each do |k, v|
              embedded_doc_changes["#{rel}.#{k}"] = [v.first, v.last]
            end
          end
          embedded_doc_changes
        end

        # @param [String] relation
        # @param [String] value
        #
        # @return [Hash<String, Array<(?,?)>>]
        def embeds_one_changes_from_parent(relation, value)
          relation = trackable_class.database_field_name(relation)
          relation_class = trackable_class.relation_class_of(relation)
          paranoia_field = Mongoid::History.trackable_class_settings(relation_class)[:paranoia_field]
          original_value = value[0][paranoia_field].present? ? {} : format_embeds_one_relation(relation, value[0])
          modified_value = value[1][paranoia_field].present? ? {} : format_embeds_one_relation(relation, value[1])
          return if original_value == modified_value

          { relation => [original_value, modified_value] }
        end

        # @param [String] relation
        # @param [String] value
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
