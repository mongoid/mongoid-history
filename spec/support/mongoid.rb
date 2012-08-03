ENV["MONGOID_ENV"] = "test"
Mongoid.load!("config/mongoid.yml")

RSpec.configure do |config|
  config.before :each do
    Mongoid.observers = Mongoid::History::Sweeper
  end
  config.backtrace_clean_patterns = [
    # /\/lib\d*\/ruby\//,
    # /bin\//,
    # /gems/,
    # /spec\/spec_helper\.rb/,
    /lib\/rspec\/(core|expectations|matchers|mocks)/
    ]
end


