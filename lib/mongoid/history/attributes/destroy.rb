module Mongoid
  module History
    module Attributes
      class Destroy < ::Mongoid::History::Attributes::Base
        def attributes
          @attributes = {}
          trackable.attributes.each { |k, v| @attributes[k] = [v, nil] if trackable_class.tracked_field?(k, :destroy) }
          insert_embeds_one_changes
          insert_embeds_many_changes
          @attributes
        end

        private

        def insert_embeds_one_changes
          trackable_class.tracked_embeds_one
            .map { |rel| aliased_fields.key(rel) || rel }
            .each do |rel|
              permitted_attrs = trackable_class.tracked_embeds_one_attributes(rel)
              obj = trackable.send(rel)
              @attributes[rel] = [obj.attributes.slice(*permitted_attrs), nil] if obj
            end
        end

        def insert_embeds_many_changes
          trackable_class.tracked_embeds_many
            .map { |rel| aliased_fields.key(rel) || rel }
            .each do |rel|
              permitted_attrs = trackable_class.tracked_embeds_many_attributes(rel)
              @attributes[rel] = [trackable.send(rel).map { |obj| obj.attributes.slice(*permitted_attrs) }, nil]
            end
        end
      end
    end
  end
end
