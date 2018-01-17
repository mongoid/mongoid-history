module Mongoid
  module History
    module Attributes
      class Base
        attr_reader :trackable

        def initialize(trackable)
          @trackable = trackable
        end

        private

        def trackable_class
          @trackable_class ||= trackable.class
        end

        def aliased_fields
          @aliased_fields ||= trackable_class.aliased_fields
        end

        def changes_method
          trackable_class.history_trackable_options[:changes_method]
        end

        def changes
          trackable.send(changes_method)
        end

        def format_field(field, value)
          format_value(value, trackable_class.field_format(field))
        end

        def format_embeds_one_relation(rel, obj)
          rel = trackable_class.database_field_name(rel)
          relation_class = trackable_class.relation_class_of(rel)
          permitted_attrs = trackable_class.tracked_embeds_one_attributes(rel)
          formats = trackable_class.field_format(rel)
          format_relation(relation_class, obj, permitted_attrs, formats)
        end

        def format_embeds_many_relation(rel, obj)
          rel = trackable_class.database_field_name(rel)
          relation_class = trackable_class.relation_class_of(rel)
          permitted_attrs = trackable_class.tracked_embeds_many_attributes(rel)
          formats = trackable_class.field_format(rel)
          format_relation(relation_class, obj, permitted_attrs, formats)
        end

        def format_relation(relation_class, obj, permitted_attrs, formats)
          obj.inject({}) do |m, field_value|
            field = relation_class.database_field_name(field_value.first)
            next m unless permitted_attrs.include?(field)

            value = field_value.last
            value = format_value(field_value.last, formats[field]) if formats.class == Hash
            m.merge(field => value)
          end
        end

        def format_value(value, format)
          if format.class == String
            format % value
          elsif format.respond_to?(:call)
            format.call(value)
          else
            value
          end
        end
      end
    end
  end
end
