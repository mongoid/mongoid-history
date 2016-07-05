require 'spec_helper'

describe Mongoid::History::Trackable do
  describe 'SettingsSingletonMethods' do
    describe '#default_history_settings' do
      before(:each) { model_one.history_settings }

      let(:model_one) do
        Class.new do
          include Mongoid::Document
          include Mongoid::History::Trackable

          def self.name
            'ModelOne'
          end
        end
      end

      let(:default_settings) { { paranoia_field: :deleted_at } }

      it { expect(model_one.default_history_settings).to eq(default_settings) }
    end

    describe '#trackable_settings' do
      before(:each) do
        Mongoid::History.trackable_settings = nil
        model_one.history_settings paranoia_field: :killed_at
      end

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

      it { expect(model_one.trackable_settings).to eq(paranoia_field: 'killed_at') }
    end
  end
end
