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
          trackable_class.obfuscated_field?(field) ? obfuscated_value : value
        end

        def format_embeds_one_relation(rel, obj)
          permitted_attrs = trackable_class.tracked_embeds_one_attributes(rel)
          obfuscated_attrs = trackable_class.obfuscated_embedded_attributes(rel)
          format_relation(obj, permitted_attrs, obfuscated_attrs)
        end

        def format_embeds_many_relation(rel, obj)
          permitted_attrs = trackable_class.tracked_embeds_many_attributes(rel)
          obfuscated_attrs = trackable_class.obfuscated_embedded_attributes(rel)
          format_relation(obj, permitted_attrs, obfuscated_attrs)
        end

        def format_relation(obj, permitted_attrs, obfuscated_attrs)
          return obfuscated_value if obfuscated_attrs === true

          obj = obj.slice(*permitted_attrs)

          unless obfuscated_attrs.nil? || obfuscated_attrs.size == 0
            (obj.keys & obfuscated_attrs).each do |k|
              obj[k] = obfuscated_value
            end
          end

          obj
        end

        def obfuscated_value
          '*' * 8
        end
      end
    end
  end
end
