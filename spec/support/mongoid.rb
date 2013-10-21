Mongoid.configure do |config|
  config.connect_to('mongoid_history_test')
end

RSpec.configure do |config|
  config.after(:each) do
    Mongoid.purge!
  end

  config.backtrace_exclusion_patterns = [ /lib\/rspec\/(core|expectations|matchers|mocks)/ ]
end
