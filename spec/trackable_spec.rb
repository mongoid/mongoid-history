require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Mongoid::History::Trackable do
  before :each do
    class HistoryTracker
      include Mongoid::History::Tracker
    end

    class MyModel
      include Mongoid::Document
      include Mongoid::History::Trackable
    end
  end

  after :each do
    Mongoid::History.trackable_class_options = nil
  end

  it "should have #track_history" do
    MyModel.should respond_to :track_history
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
        :changes_method =>  :changes,
        :scope          =>  :my_model,
        :except         =>  ["created_at", "updated_at", "version", "modifier_id", "_id", "id"],
        :track_create   =>  false,
        :track_update   =>  true,
        :track_destroy  =>  false,
      }
    end

    after :each do
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

    context "sub-model" do
      before :each do
        class MySubModel < MyModel
        end
      end

      it "should have default options" do
        Mongoid::History.trackable_class_options[:my_model].should == @expected_option
      end

      it "should define #history_trackable_options" do
        MySubModel.history_trackable_options.should == @expected_option
      end
    end

    context "track_history" do

      it "should be enabled on the current thread" do
        MyModel.new.track_history?.should == true
      end

      it "should be disabled within disable_tracking" do
        MyModel.disable_tracking do
          MyModel.new.track_history?.should == false
        end
      end

      it "should be rescued if an exception occurs" do
        begin
          MyModel.disable_tracking do
            raise "exception"
          end
        rescue
        end
        MyModel.new.track_history?.should == true
      end

      it "should be disabled only for the class that calls disable_tracking" do
        class MyModel2
          include Mongoid::Document
          include Mongoid::History::Trackable
          track_history
        end

        MyModel.disable_tracking do
          MyModel2.new.track_history?.should == true
        end
      end

      context ":changes_method" do
        it "should default to :changes" do
          m = MyModel.create
          m.should_receive(:changes).twice.and_call_original
          m.save
        end

        it "should allow an alternate method to be specified" do
          class MyModel3 < MyModel
            track_history :changes_method => :my_changes

            def my_changes
              {}
            end
          end

          m = MyModel3.create
          m.should_receive(:changes).once.and_call_original
          m.should_receive(:my_changes).once.and_call_original
          m.save
        end
      end
    end
  end
end
