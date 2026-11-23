module Mongoid
  module History
    # Maps stable history identities to the currently loaded model names.
    module Aliases
      def trackable_aliases
        @trackable_aliases ||= {}
      end

      def register_trackable_alias(klass, name)
        valid = (name.is_a?(String) || name.is_a?(Symbol)) && name.to_s.strip.present? && klass.name.present?
        raise ArgumentError, ':as must be a nonempty string or symbol on a named model' unless valid

        name = name.to_s
        registered = trackable_aliases[name]
        existing = registered.safe_constantize if registered
        existing ||= name.safe_constantize
        raise ArgumentError, "History alias #{name.inspect} is already used by #{existing.name}" if existing && existing != klass

        trackable_aliases[name] = klass.name
      end

      def trackable_class_for(name)
        (trackable_aliases[name.to_s] || name.to_s).constantize
      end

      def prepare_trackable_alias(klass, options)
        return options if options[:as].nil?

        register_trackable_alias(klass, options[:as])
        options.key?(:scope) ? options : options.merge(scope: options[:as].to_s.to_sym)
      end

      def trackable_name(klass)
        options = klass.mongoid_history_options if klass.respond_to?(:mongoid_history_options)
        (options && options.options[:as] || klass.name).to_s
      end
    end
  end
end
