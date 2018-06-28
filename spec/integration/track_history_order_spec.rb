require 'spec_helper'

describe Mongoid::History::Tracker do
  context 'when track_history not called' do
    before :each do
      class NotModel
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :foo
      end
    end

    after :each do
      Object.send(:remove_const, :NotModel)
    end

    it 'should not track fields' do
      expect(NotModel.respond_to?(:tracked?)).to be false
    end
  end

  context 'boefore field' do
    before :each do
      class InsideBeforeModel
        include Mongoid::Document
        include Mongoid::History::Trackable

        track_history on: :fields

        field :foo
      end
    end

    after :each do
      Object.send(:remove_const, :InsideBeforeModel)
    end

    it 'should track fields' do
      expect(InsideBeforeModel.tracked?(:foo)).to be true
    end
  end

  context 'when track_history called inside class and after fields' do
    before :each do
      class InsideAfterModel
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :foo

        track_history on: :fields
      end
    end

    after :each do
      Object.send(:remove_const, :InsideAfterModel)
    end

    it 'should track fields' do
      expect(InsideAfterModel.tracked?(:foo)).to be true
    end
  end

  context 'when track_history called outside class' do
    before :each do
      class OutsideModel
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :foo
      end
    end

    after :each do
      Object.send(:remove_const, :OutsideModel)
    end

    it 'should track fields' do
      OutsideModel.track_history on: :fields
      expect(OutsideModel.tracked?(:foo)).to be true
    end
  end
end
