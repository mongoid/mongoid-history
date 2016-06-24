require 'spec_helper'

describe Mongoid::History do
  describe '.store' do
    it 'should return RequestStore if requested' do
      if ENV['REQUEST_STORE_VERSION']
        expect(described_class.store).to be_a Hash
      else
        expect(described_class.store).to be_a Thread
      end
    end
  end
end
