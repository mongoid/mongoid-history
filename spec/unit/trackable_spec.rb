require 'spec_helper'

class MyModel
  include Mongoid::Document
  include Mongoid::History::Trackable
  field :foo
end

class HistoryTracker
  include Mongoid::History::Tracker
end

describe Mongoid::History::Trackable do
  it "should have #track_history" do
    MyModel.should respond_to :track_history
  end

  it "should append trackable_class_options ONLY when #track_history is called" do
    Mongoid::History.trackable_class_options.should be_blank
    MyModel.track_history
    Mongoid::History.trackable_class_options.keys.should == [:my_model]
  end

  describe "#track_history" do
    before :all do
      MyModel.track_history
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }
    let(:expected_option) do
      { on: :all,
        modifier_field: :modifier,
        version_field: :version,
        changes_method: :changes,
        scope: :my_model,
        except: ["created_at", "updated_at"],
        track_create: false,
        track_update: true,
        track_destroy: false }
    end
    let(:regular_fields) { ["foo"] }
    let(:reserved_fields) { ["_id", "version", "modifier_id"] }

    it "should have default options" do
      Mongoid::History.trackable_class_options[:my_model].should == expected_option
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
      MyModel.history_trackable_options.should == expected_option
    end

    describe "#tracked_fields" do
      it "should return the tracked field list" do
        MyModel.tracked_fields.should == regular_fields
      end
    end

    describe "#reserved_tracked_fields" do
      it "should return the protected field list" do
        MyModel.reserved_tracked_fields.should == reserved_fields
      end
    end

    describe "#tracked_fields_for_action" do
      it "should include the reserved fields for destroy" do
        MyModel.tracked_fields_for_action(:destroy).should == regular_fields + reserved_fields
      end
      it "should not include the reserved fields for update" do
        MyModel.tracked_fields_for_action(:update).should == regular_fields
      end
      it "should not include the reserved fields for create" do
        MyModel.tracked_fields_for_action(:create).should == regular_fields
      end
    end

    describe "#tracked_field?" do
      it "should not include the reserved fields by default" do
        MyModel.tracked_field?(:_id).should be_falsey
      end
      it "should include the reserved fields for destroy" do
        MyModel.tracked_field?(:_id, :destroy).should be_truthy
      end
      it "should allow field aliases" do
        MyModel.tracked_field?(:id, :destroy).should be_truthy
      end
    end

    context "sub-model" do
      before :each do
        class MySubModel < MyModel
        end
      end

      it "should have default options" do
        Mongoid::History.trackable_class_options[:my_model].should == expected_option
      end

      it "should define #history_trackable_options" do
        MySubModel.history_trackable_options.should == expected_option
      end
    end

    describe "#track_history?" do

      context "when tracking is globally enabled" do

        it "should be enabled on the current thread" do
          Mongoid::History.enabled?.should == true
          MyModel.new.track_history?.should == true
        end

        it "should be disabled within disable_tracking" do
          MyModel.disable_tracking do
            Mongoid::History.enabled?.should == true
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
          Mongoid::History.enabled?.should == true
          MyModel.new.track_history?.should == true
        end

        it "should be disabled only for the class that calls disable_tracking" do
          class MyModel2
            include Mongoid::Document
            include Mongoid::History::Trackable
            track_history
          end

          MyModel.disable_tracking do
            Mongoid::History.enabled?.should == true
            MyModel2.new.track_history?.should == true
          end
        end
      end

      context "when tracking is globally disabled" do

        around(:each) do |example|
          Mongoid::History.disable do
            example.run
          end
        end

        it "should be disabled by the global disablement" do
          Mongoid::History.enabled?.should == false
          MyModel.new.track_history?.should == false
        end

        it "should be disabled within disable_tracking" do
          MyModel.disable_tracking do
            Mongoid::History.enabled?.should == false
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
          Mongoid::History.enabled?.should == false
          MyModel.new.track_history?.should == false
        end

        it "should be disabled only for the class that calls disable_tracking" do
          class MyModel2
            include Mongoid::Document
            include Mongoid::History::Trackable
            track_history
          end

          MyModel.disable_tracking do
            Mongoid::History.enabled?.should == false
            MyModel2.new.track_history?.should == false
          end
        end
      end

      it "should rescue errors through both local and global tracking scopes" do
        begin
          Mongoid::History.disable do
            MyModel.disable_tracking do
              raise "exception"
            end
          end
        rescue
        end
        Mongoid::History.enabled?.should == true
        MyModel.new.track_history?.should == true
      end
    end

    describe ":changes_method" do

      it "should default to :changes" do
        m = MyModel.create
        m.should_receive(:changes).exactly(3).times.and_call_original
        m.should_not_receive(:my_changes)
        m.save
      end

      it "should allow an alternate method to be specified" do
        class MyModel3 < MyModel
          track_history changes_method: :my_changes

          def my_changes
            {}
          end
        end

        m = MyModel3.create
        m.should_receive(:changes).twice.and_call_original
        m.should_receive(:my_changes).once.and_call_original
        m.save
      end
    end
  end
end
