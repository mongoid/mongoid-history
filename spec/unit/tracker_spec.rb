require 'spec_helper'

describe Mongoid::History::Tracker do
  before do
    @tracker_class_name = Mongoid::History.tracker_class_name
    Mongoid::History.tracker_class_name = nil
  end

  it 'should set tracker_class_name when included' do
    class MyTracker
      include Mongoid::History::Tracker
    end
    expect(Mongoid::History.tracker_class_name).to eq(:my_tracker)
  end

  after do
    Mongoid::History.tracker_class_name = @tracker_class_name
  end
end
