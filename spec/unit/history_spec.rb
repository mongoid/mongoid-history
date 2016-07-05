require 'spec_helper'

describe Mongoid::History do
  it { is_expected.to respond_to(:trackable_settings) }
  it { is_expected.to respond_to(:trackable_settings=) }

  it { expect(described_class.trackable_settings).to eq({}) }
end
