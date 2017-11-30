require 'spec_helper'

describe Mongoid::History::Trackable do
  describe 'EmbeddedMethods' do
    describe 'embeds_one_class' do
      before :all do
        class ModelOne
          include Mongoid::Document
          include Mongoid::History::Trackable
          embeds_one :emb_one, inverse_class_name: 'EmbOne'
          embeds_one :emb_two, store_as: 'emt', inverse_class_name: 'EmbTwo'
          track_history
        end

        class EmbOne
          include Mongoid::Document
          embedded_in :model_one
        end

        class EmbTwo
          include Mongoid::Document
          embedded_in :model_one
        end
      end

      it { expect(ModelOne.embeds_one_class('emb_one')).to eq EmbOne }
      it { expect(ModelOne.embeds_one_class('emt')).to eq EmbTwo }
      it { expect(ModelOne.embeds_one_class('invalid')).to be_nil }

      after :all do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
        Object.send(:remove_const, :EmbTwo)
      end
    end

    describe 'embeds_many_class' do
      before :all do
        class ModelOne
          include Mongoid::Document
          include Mongoid::History::Trackable
          embeds_many :emb_ones, inverse_class_name: 'EmbOne'
          embeds_many :emb_twos, store_as: 'emts', inverse_class_name: 'EmbTwo'
          track_history
        end

        class EmbOne
          include Mongoid::Document
          embedded_in :model_one
        end

        class EmbTwo
          include Mongoid::Document
          embedded_in :model_one
        end
      end

      it { expect(ModelOne.embeds_many_class('emb_ones')).to eq EmbOne }
      it { expect(ModelOne.embeds_many_class('emts')).to eq EmbTwo }
      it { expect(ModelOne.embeds_many_class('invalid')).to be_nil }

      after :all do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
        Object.send(:remove_const, :EmbTwo)
      end
    end
  end
end
