require 'coveralls'
Coveralls.wear!

$LOAD_PATH.push File.expand_path('../../lib', __FILE__)

require 'active_support/all'
require 'mongoid'
require 'request_store'

# Undefine RequestStore so that it may be stubbed in specific tests
RequestStoreTemp = RequestStore
Object.send(:remove_const, :RequestStore)

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'mongoid/history'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.before :all do
    Mongoid.logger.level = Logger::INFO
    Mongo::Logger.logger.level = Logger::INFO if Mongoid::Compatibility::Version.mongoid5? || Mongoid::Compatibility::Version.mongoid6?
    Mongoid.belongs_to_required_by_default = false if Mongoid::Compatibility::Version.mongoid6?
  end
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end
