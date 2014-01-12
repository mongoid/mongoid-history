$LOAD_PATH.push File.expand_path('../../lib', __FILE__)

require 'active_support/all'
require 'mongoid'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'mongoid-history'
