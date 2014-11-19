module Mongoid
  module History
    def self.mongoid3?
      ::Mongoid::VERSION > '2' && ::Mongoid::VERSION < '4'
    end
  end
end
