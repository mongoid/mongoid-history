require 'versionomy'

module Mongoid
  module History
    def self.mongoid3?
      Versionomy.parse(::Mongoid::VERSION).major == 3
    end
  end
end
