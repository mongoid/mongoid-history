module Mongoid
  module History
    class Options
      # Resolves association selectors to the fields stored in history records.
      module Relations
        private

        def prepare_relations
          if @prepared[:on].include?(:embedded_relations)
            @prepared[:on] = @prepared[:on].reject { |opt| opt == :embedded_relations } |
                             trackable.embedded_relations.keys
          end
          prepare_referenced_relations
        end

        def prepare_referenced_relations
          return unless @prepared[:on].include?(:referenced_relations)

          @prepared[:on] = @prepared[:on].reject { |opt| opt == :referenced_relations } |
                           trackable.reflect_on_all_associations(:has_and_belongs_to_many).map(&:name)
        end

        def history_field_name(field)
          relation = trackable.reflect_on_all_associations(:has_and_belongs_to_many).find do |meta|
            meta.name.to_s == field.to_s
          end
          trackable.database_field_name(relation ? relation.foreign_key : field)
        end
      end
    end
  end
end
