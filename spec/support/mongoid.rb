Mongoid.configure do |config|
  config.master = Mongo::Connection.new.db("mongoid-history")
end

RSpec.configure do |config|
  config.before :each do
    Mongoid.observers = Mongoid::History::Sweeper
  end
end


