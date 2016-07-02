require 'spec_helper'

describe 'RequestStore' do
  before { stub_const('RequestStore', RequestStoreTemp) }

  describe 'Mongoid::History' do
    describe '.store' do
      it 'should return RequestStore' do
        expect(Mongoid::History.store).to be_a Hash
      end
    end
  end
end
