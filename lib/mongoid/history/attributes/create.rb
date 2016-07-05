module Mongoid
  module History
    module Attributes
      class Create < ::Mongoid::History::Attributes::Base
        def attributes
          @attributes = {}
          trackable.attributes.each { |k, v| @attributes[k] = [nil, v] if trackable_class.tracked_field?(k, :create) }
          insert_embeds_one_changes
          insert_embeds_many_changes
          @attributes
        end

        private

        def insert_embeds_one_changes
          trackable_class.tracked_embeds_one.each do |rel|
            rel_class = trackable_class.embeds_one_class(rel)
            paranoia_field = Mongoid::History.trackable_class_settings(rel_class)[:paranoia_field]
            paranoia_field = rel_class.aliased_fields.key(paranoia_field) || paranoia_field
            permitted_attrs = trackable_class.tracked_embeds_one_attributes(rel)
            rel = aliased_fields.key(rel) || rel
            obj = trackable.send(rel)
            next if !obj || (obj.respond_to?(paranoia_field) && obj.public_send(paranoia_field).present?)
            @attributes[rel] = [nil, obj.attributes.slice(*permitted_attrs)]
          end
        end

        def insert_embeds_many_changes
          trackable_class.tracked_embeds_many.each do |rel|
            rel_class = trackable_class.embeds_many_class(rel)
            paranoia_field = Mongoid::History.trackable_class_settings(rel_class)[:paranoia_field]
            paranoia_field = rel_class.aliased_fields.key(paranoia_field) || paranoia_field
            permitted_attrs = trackable_class.tracked_embeds_many_attributes(rel)
            rel = aliased_fields.key(rel) || rel
            @attributes[rel] = [nil,
                                trackable.send(rel)
                                .reject { |obj| obj.respond_to?(paranoia_field) && obj.public_send(paranoia_field).present? }
                                .map { |obj| obj.attributes.slice(*permitted_attrs) }]
          end
        end
      end
    end
  end
end
