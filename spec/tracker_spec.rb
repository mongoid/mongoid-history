require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Mongoid::History::Tracker do
  before :each do
    class MyTracker
      include Mongoid::History::Tracker
    end
  end
  
  after :each do
    Mongoid::History.tracker_class_name = nil
  end
  
  it "should set tracker_class_name when included" do
    Mongoid::History.tracker_class_name.should == :my_tracker
  end
end
