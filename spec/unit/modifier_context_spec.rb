require 'spec_helper'

describe 'Modifier context' do
  shared_examples 'scoped storage' do
    it 'restores nested scopes, nil and the absence of a context, even after exceptions' do
      storage = Mongoid::History.store
      key = Mongoid::History::MODIFIER_KEY
      expect(storage[key]).to be_nil
      result = Mongoid::History.with_modifier(:alice) do
        expect(storage[key]).to eq([:alice])
        expect do
          Mongoid::History.with_modifier(nil) do
            expect(storage.key?(key)).to be true
            expect(storage[key]).to eq([nil])
            raise 'failed'
          end
        end.to raise_error('failed')
        expect(storage[key]).to eq([:alice])
        :result
      end
      expect(result).to eq(:result)
      expect(storage[key]).to be_nil
    end
  end

  context 'with thread storage' do
    include_examples 'scoped storage'

    it 'does not share a modifier with another thread' do
      Mongoid::History.with_modifier(:alice) do
        expect(Thread.new { Mongoid::History.store[Mongoid::History::MODIFIER_KEY] }.value).to be_nil
      end
    end
  end

  context 'with RequestStore' do
    before { stub_const('RequestStore', RequestStoreTemp) }
    include_examples 'scoped storage'
  end

  it 'wraps a controller action using a private, configurable current user method and cleans up on error' do
    controller_class = Class.new do
      def self.around_action(method)
        @history_callback = method
      end

      class << self
        attr_reader :history_callback
      end

      include Mongoid::History::Hooks::Modifier

      private

      def current_person
        :alice
      end
    end
    previous_method = Mongoid::History.current_user_method
    begin
      Mongoid::History.current_user_method = :current_person
      expect do
        controller_class.new.send(controller_class.history_callback) do
          expect(Mongoid::History.store[Mongoid::History::MODIFIER_KEY]).to eq([:alice])
          raise 'action failed'
        end
      end.to raise_error('action failed')
      expect(Mongoid::History.store[Mongoid::History::MODIFIER_KEY]).to be_nil
    ensure
      Mongoid::History.current_user_method = previous_method
    end
  end
end
