require 'spec_helper'

describe Mongoid::History::Tracker do
  before { Mongoid::History.tracker_class_name = nil }
  it 'should set tracker_class_name when included' do
    class MyTracker
      include Mongoid::History::Tracker
    end
    expect(Mongoid::History.tracker_class_name).to eq(:my_tracker)
  end
end
