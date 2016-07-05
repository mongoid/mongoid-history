require 'spec_helper'

describe Mongoid::History do
  it { is_expected.to respond_to(:trackable_settings) }
  it { is_expected.to respond_to(:trackable_settings=) }

  it { expect(described_class.trackable_settings).to eq({}) }

  describe '#default_settings' do
    let(:default_settings) { { paranoia_field: 'deleted_at' } }
    it { expect(described_class.default_settings).to eq(default_settings) }
  end
end
