Mongoid.configure do |config|
  config.connect_to('mongoid_history_test')
end

RSpec.configure do |config|
  config.before :each do
    Mongoid.observers = Mongoid::History::Sweeper
  end

  config.after(:each) do
    Mongoid.purge!
  end

  config.backtrace_clean_patterns = [ /lib\/rspec\/(core|expectations|matchers|mocks)/ ]
end