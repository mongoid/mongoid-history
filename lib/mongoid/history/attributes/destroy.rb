module Mongoid
  module History
    module Attributes
      class Destroy < ::Mongoid::History::Attributes::Base
        def attributes
          @attributes = {}
          trackable.attributes.each { |k, v| @attributes[k] = [format_field(k, v), nil] if trackable_class.tracked_field?(k, :destroy) }
          insert_embeds_one_changes
          insert_embeds_many_changes
          @attributes
        end

        private

        def insert_embeds_one_changes
          trackable_class.tracked_embeds_one
                         .map { |rel| aliased_fields.key(rel) || rel }
                         .each do |rel|
            obj = trackable.send(rel)
            @attributes[rel] = [format_embeds_one_relation(rel, obj.attributes), nil] if obj
          end
        end

        def insert_embeds_many_changes
          trackable_class.tracked_embeds_many
                         .map { |rel| aliased_fields.key(rel) || rel }
                         .each do |rel|
            @attributes[rel] = [trackable.send(rel).map { |obj| format_embeds_many_relation(rel, obj.attributes) }, nil]
          end
        end
      end
    end
  end
end
