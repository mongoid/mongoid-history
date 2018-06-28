require 'spec_helper'

describe Mongoid::History do
  before :each do
    class First
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :text, type: String
      track_history on: [:text], tracker_class_name: :first_history_tracker
    end

    class Second
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :text, type: String
      track_history on: [:text], tracker_class_name: :second_history_tracker
    end

    class User
      include Mongoid::Document
    end

    class FirstHistoryTracker
      include Mongoid::History::Tracker
    end

    class SecondHistoryTracker
      include Mongoid::History::Tracker
    end
  end

  after :each do
    Object.send(:remove_const, :First)
    Object.send(:remove_const, :Second)
    Object.send(:remove_const, :User)
    Object.send(:remove_const, :FirstHistoryTracker)
    Object.send(:remove_const, :SecondHistoryTracker)
  end

  let(:user) { User.create! }

  it 'should be possible to have different trackers for each class' do
    expect(FirstHistoryTracker.count).to eq(0)
    expect(SecondHistoryTracker.count).to eq(0)
    expect(First.tracker_class).to be FirstHistoryTracker
    expect(Second.tracker_class).to be SecondHistoryTracker

    foo = First.create!(modifier: user)
    bar = Second.create!(modifier: user)

    expect(FirstHistoryTracker.count).to eq 1
    expect(SecondHistoryTracker.count).to eq 1

    foo.update_attributes!(text: "I'm foo")
    bar.update_attributes!(text: "I'm bar")

    expect(FirstHistoryTracker.count).to eq 2
    expect(SecondHistoryTracker.count).to eq 2

    foo.destroy
    bar.destroy

    expect(FirstHistoryTracker.count).to eq 3
    expect(SecondHistoryTracker.count).to eq 3
  end
end
