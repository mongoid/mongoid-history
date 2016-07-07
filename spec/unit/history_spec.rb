require 'spec_helper'

describe Mongoid::History do
  it { is_expected.to respond_to(:trackable_settings) }
  it { is_expected.to respond_to(:trackable_settings=) }

  describe '#default_settings' do
    let(:default_settings) { { paranoia_field: 'deleted_at' } }
    it { expect(described_class.default_settings).to eq(default_settings) }
  end

  describe '#trackable_class_settings' do
    before(:each) { Mongoid::History.trackable_settings = {} }
    let(:model_one) do
      Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        store_in collection: :model_ones

        def self.name
          'ModelOne'
        end
      end
    end

    context 'when present' do
      before(:each) { model_one.history_settings paranoia_field: :annuled_at }
      it { expect(described_class.trackable_class_settings(model_one)).to eq(paranoia_field: 'annuled_at') }
    end

    context 'when not present' do
      it { expect(described_class.trackable_class_settings(model_one)).to eq(paranoia_field: 'deleted_at') }
    end
  end
end
