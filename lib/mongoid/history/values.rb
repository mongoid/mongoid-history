module Mongoid
  module History
    # Reads stored history through the tracked document's field serializers.
    module Values
      def database_original
        read_attribute(:original)
      end

      def database_modified
        read_attribute(:modified)
      end

      private

      def typed_history_values(values)
        values.empty? ? values.dup : demongoize_history_values(values, history_value_class)
      end

      def history_value_class
        association_chain.drop(1).inject(trackable_parent_class) do |klass, node|
          history_value_relation(klass, node['name']).class_name.constantize
        end
      end

      def history_value_relation(klass, name)
        klass.relations.values.find { |relation| relation.key.to_s == name.to_s || relation.name.to_s == name.to_s }
      end

      def demongoize_history_values(values, klass)
        values.each_with_object({}) do |(name, value), result|
          field = klass.fields[name.to_s]
          relation = history_value_relation(klass, name) unless field
          result[name] = if value.nil?
                           nil
                         elsif field && !field.localized?
                           field.demongoize(copy_history_value(value))
                         elsif relation && value.is_a?(Hash)
                           demongoize_history_values(value, relation.class_name.constantize)
                         elsif relation && value.is_a?(Array)
                           value.map { |attributes| demongoize_history_values(attributes, relation.class_name.constantize) }
                         else
                           copy_history_value(value)
                         end
        end
      end

      def copy_history_value(value)
        case value
        when Hash
          value.each_with_object(value.dup.clear) { |(key, item), copy| copy[key] = copy_history_value(item) }
        when Array
          value.map { |item| copy_history_value(item) }
        else
          value.duplicable? ? value.dup : value
        end
      end
    end
  end
end
