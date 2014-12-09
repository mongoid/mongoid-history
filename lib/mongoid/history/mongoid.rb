module Mongoid
  module History
    def self.mongoid3?
      Mongoid::VERSION =~ /^3\./
    end
  end
end
