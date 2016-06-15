require 'coveralls'
Coveralls.wear!

$LOAD_PATH.push File.expand_path('../../lib', __FILE__)

require 'active_support/all'
require 'mongoid'
require 'request_store' if ENV['USE_REQUEST_STORE']

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'mongoid/history'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.before :all do
    Mongoid.logger.level = Logger::INFO
    Mongo::Logger.logger.level = Logger::INFO if Mongoid::Compatibility::Version.mongoid5?
  end
end
