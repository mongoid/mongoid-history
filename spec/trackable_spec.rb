require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Mongoid::History::Trackable do
  before :each do
    class MyModel
      include Mongoid::Document
      include Mongoid::History::Trackable
    end
  end
  
  after :each do
    Mongoid::History.trackable_classes = nil
    Mongoid::History.trackable_class_options = nil
  end

  it "should have #track_history" do
    MyModel.should respond_to :track_history
  end
  
  it "should append trackable_classes ONLY when #track_history is called" do
    Mongoid::History.trackable_classes.should be_blank
    MyModel.track_history
    Mongoid::History.trackable_classes.should == [MyModel]
  end
  
  it "should append trackable_class_options ONLY when #track_history is called" do
    Mongoid::History.trackable_class_options.should be_blank
    MyModel.track_history
    Mongoid::History.trackable_class_options.keys.should == [:my_model]
  end
  
  describe "#track_history" do
    before :each do
      class MyModel
        include Mongoid::Document
        include Mongoid::History::Trackable
        track_history
      end
      
      @expected_option = {
        :on             =>  :all,
        :modifier_field =>  :modifier,
        :version_field  =>  :version,
        :scope          =>  :my_model,
        :except         =>  ["created_at", "updated_at", "version", "modifier_id", "_id", "id"],
        :track_create   =>  false,
        :track_destroy  =>  false,
      }
    end
    
    after :each do
      Mongoid::History.trackable_classes = nil
      Mongoid::History.trackable_class_options = nil
    end
    
    it "should have default options" do
      Mongoid::History.trackable_class_options[:my_model].should == @expected_option
    end
    
    it "should define callback function #track_update" do
      MyModel.new.private_methods.collect(&:to_sym).should include(:track_update)
    end
    
    it "should define callback function #track_create" do
      MyModel.new.private_methods.collect(&:to_sym).should include(:track_create)
    end

    it "should define callback function #track_destroy" do
      MyModel.new.private_methods.collect(&:to_sym).should include(:track_destroy)
    end

    it "should define #history_trackable_options" do
      MyModel.history_trackable_options.should == @expected_option
    end
  end
end
