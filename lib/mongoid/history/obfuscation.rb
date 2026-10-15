module Mongoid
  module History
    # Replaces configured values in snapshots before they are persisted.
    module Obfuscation
      FILTERED = '[FILTERED]'.freeze

      def self.prepare(attributes, trackable)
        fields = Array(trackable.history_trackable_options[:obfuscate]).flat_map { |field| paths(trackable.class, field.to_s) }.uniq
        return attributes if fields.empty?

        snapshots = attributes.values_at(:original, :modified).map(&:deep_dup)
        fields = apply(snapshots, fields)
        return attributes if fields.empty?

        attributes.merge(original: snapshots.first, modified: snapshots.last, obfuscated_fields: fields)
      end

      def self.paths(klass, field)
        head, tail = field.split('.', 2)
        database_name = klass.database_field_name(head)
        names = [head, database_name].uniq
        return names unless tail

        relation = klass.relations.values.find { |item| item.key.to_s == database_name || item.name.to_s == head }
        tails = relation ? paths(relation.class_name.constantize, tail) : [tail]
        names.product(tails).map { |name, nested| "#{name}.#{nested}" }
      end

      def self.apply(snapshots, fields)
        fields.select do |field|
          snapshots.map { |snapshot| replace(snapshot, field.split('.')) }.any?
        end
      end

      def self.replace(value, path)
        return value.map { |item| replace(item, path) }.any? if value.is_a?(Array)
        return false unless value.is_a?(Hash)

        [path.first, path.first.to_sym].map do |key|
          next false unless value.key?(key)

          if path.length > 1
            replace(value[key], path.drop(1))
          elsif value[key].nil?
            false
          else
            value[key] = FILTERED
            true
          end
        end.any?
      end
    end
  end
end
