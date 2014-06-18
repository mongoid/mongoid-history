require 'coveralls'
Coveralls.wear!

$LOAD_PATH.push File.expand_path('../../lib', __FILE__)

require 'active_support/all'
require 'mongoid'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'mongoid-history'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = [:should, :expect]
  end
  config.mock_with :rspec do |mocks|
    mocks.syntax = [:should, :expect]
  end
end
