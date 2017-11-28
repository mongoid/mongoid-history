require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class SpecModel
      include Mongoid::Document
      include Mongoid::History::Trackable

      track_history on: :fields

      field :foo
    end
  end

  it 'should track all fields when field added after track_history' do
    expect(SpecModel.tracked?(:foo)).to be true
  end
end
