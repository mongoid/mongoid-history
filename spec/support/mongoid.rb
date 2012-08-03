Mongoid.configure do |config|
  # config.master = Mongo::Connection.new.db("mongoid-history")
  config.connect_to("mongoid-history")
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
    
  config.before :each do
    Mongoid.observers = Mongoid::History::Sweeper
  end
end


