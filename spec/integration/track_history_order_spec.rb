require 'spec_helper'

describe Mongoid::History::Tracker do
  it 'should not track fields when track_history not called' do
    class NotModel
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :foo
    end

    expect(NotModel.respond_to?(:tracked?)).to be false
  end

  it 'should track fields when track_history called inside class and before fields' do
    class InsideBeforeModel
      include Mongoid::Document
      include Mongoid::History::Trackable

      track_history on: :fields

      field :foo
    end

    expect(InsideBeforeModel.tracked?(:foo)).to be true
  end

  it 'should track fields when track_history called inside class and after fields' do
    class InsideAfterModel
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :foo

      track_history on: :fields
    end

    expect(InsideAfterModel.tracked?(:foo)).to be true
  end

  it 'should track fields when track_history called outside class' do
    class OutsideModel
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :foo
    end

    OutsideModel.track_history on: :fields
    expect(OutsideModel.tracked?(:foo)).to be true
  end
end
