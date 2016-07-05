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

        def changes
          trackable.send(changes_method)
        end

        def changes_method
          trackable_class.history_trackable_options[:changes_method]
        end
      end
    end
  end
end
