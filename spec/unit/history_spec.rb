require 'spec_helper'

describe Mongoid::History do
  it { is_expected.to respond_to(:trackable_settings) }
  it { is_expected.to respond_to(:trackable_settings=) }

  describe '#default_settings' do
    let(:default_settings) { { paranoia_field: 'deleted_at' } }
    it { expect(described_class.default_settings).to eq(default_settings) }
  end

  describe '#trackable_class_settings' do
    before :each do
      class ModelOne
        include Mongoid::Document
        include Mongoid::History::Trackable

        store_in collection: :model_ones
      end
    end

    after :each do
      Object.send(:remove_const, :ModelOne)
    end

    context 'when present' do
      before :each do
        ModelOne.history_settings paranoia_field: :annuled_at
      end
      it { expect(described_class.trackable_class_settings(ModelOne)).to eq(paranoia_field: 'annuled_at') }
    end

    context 'when not present' do
      it { expect(described_class.trackable_class_settings(ModelOne)).to eq(paranoia_field: 'deleted_at') }
    end
  end

  describe '#reset!' do
    before :each do
      class ModelTwo
        include Mongoid::Document
        include Mongoid::History::Trackable

        track_history
      end
    end

    after :each do
      Object.send(:remove_const, :ModelTwo)
    end

    it 'should remove all configurations' do
      expect(ModelTwo).to have_attributes mongoid_history_options: be_a(Mongoid::History::Options)
      Mongoid::History.reset!
      expect(ModelTwo).to_not respond_to :mongoid_history_options
    end
  end
end
