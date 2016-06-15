require 'spec_helper'

describe Mongoid::History do
  describe '.store' do
    it 'should return RequestStore if requested' do
      if ENV['USE_REQUEST_STORE']
        expect(described_class.store).to be_a Hash
      else
        expect(described_class.store).to be_a Thread
      end
    end
  end
end
