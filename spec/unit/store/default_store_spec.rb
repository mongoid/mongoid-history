require 'spec_helper'

describe 'Default Store' do
  describe 'Mongoid::History' do
    describe '.store' do
      it 'should return Thread object' do
        expect(Mongoid::History.store).to be_a Thread
      end
    end
  end
end
