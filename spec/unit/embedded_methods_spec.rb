require 'spec_helper'

describe Mongoid::History::Trackable do
  describe 'EmbeddedMethods' do
    describe 'relation_class_of' do
      before :each do
        class ModelOne
          include Mongoid::Document
          include Mongoid::History::Trackable

          if Mongoid::Compatibility::Version.mongoid7_or_newer?
            embeds_one :emb_one
            embeds_one :emb_two, store_as: 'emt'
          else
            embeds_one :emb_one, inverse_class_name: 'EmbOne'
            embeds_one :emb_two, store_as: 'emt', inverse_class_name: 'EmbTwo'
          end

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

      after :each do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
        Object.send(:remove_const, :EmbTwo)
      end

      it { expect(ModelOne.relation_class_of('emb_one')).to eq EmbOne }
      it { expect(ModelOne.relation_class_of('emt')).to eq EmbTwo }
      it { expect(ModelOne.relation_class_of('invalid')).to be_nil }
    end

    describe 'relation_class_of' do
      before :each do
        class ModelOne
          include Mongoid::Document
          include Mongoid::History::Trackable

          if Mongoid::Compatibility::Version.mongoid7_or_newer?
            embeds_many :emb_ones
            embeds_many :emb_twos, store_as: 'emts'
          else
            embeds_many :emb_ones, inverse_class_name: 'EmbOne'
            embeds_many :emb_twos, store_as: 'emts', inverse_class_name: 'EmbTwo'
          end

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

      after :each do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
        Object.send(:remove_const, :EmbTwo)
      end

      it { expect(ModelOne.relation_class_of('emb_ones')).to eq EmbOne }
      it { expect(ModelOne.relation_class_of('emts')).to eq EmbTwo }
      it { expect(ModelOne.relation_class_of('invalid')).to be_nil }
    end
  end
end
