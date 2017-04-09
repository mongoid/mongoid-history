module Mongoid
  module History
    module Attributes
      class Create < ::Mongoid::History::Attributes::Base
        def attributes
          @attributes = {}
          trackable.attributes.each do |k, v|
            next unless trackable_class.tracked_field?(k, :create)
            modified = if changes[k]
                         changes[k].class == Array ? changes[k].last : changes[k]
                       else
                         v
                       end
            @attributes[k] = [nil, format_field(k, modified)]
          end
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
            rel = aliased_fields.key(rel) || rel
            obj = trackable.send(rel)
            next if !obj || (obj.respond_to?(paranoia_field) && obj.public_send(paranoia_field).present?)
            @attributes[rel] = [nil, format_embeds_one_relation(rel, obj.attributes)]
          end
        end

        def insert_embeds_many_changes
          trackable_class.tracked_embeds_many.each do |rel|
            rel_class = trackable_class.embeds_many_class(rel)
            paranoia_field = Mongoid::History.trackable_class_settings(rel_class)[:paranoia_field]
            paranoia_field = rel_class.aliased_fields.key(paranoia_field) || paranoia_field
            rel = aliased_fields.key(rel) || rel
            @attributes[rel] = [nil,
                                trackable.send(rel)
                                         .reject { |obj| obj.respond_to?(paranoia_field) && obj.public_send(paranoia_field).present? }
                                         .map { |obj| format_embeds_many_relation(rel, obj.attributes) }]
          end
        end
      end
    end
  end
end
