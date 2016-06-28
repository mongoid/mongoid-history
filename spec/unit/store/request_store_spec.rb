require 'spec_helper'

describe 'RequestStore', if: ENV['REQUEST_STORE_VERSION'].present? do
  describe 'Mongoid::History' do
    describe '.store' do
      it 'should return RequestStore' do
        expect(Mongoid::History.store).to be_a Hash
      end
    end
  end
end
