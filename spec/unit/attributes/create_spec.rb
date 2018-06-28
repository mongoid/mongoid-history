require 'spec_helper'

describe Mongoid::History::Attributes::Create do
  before :each do
    class ModelOne
      include Mongoid::Document
      include Mongoid::History::Trackable

      store_in collection: :model_ones
      field :foo
      field :b, as: :bar

      track_history on: :foo
    end
  end

  after :each do
    Object.send(:remove_const, :ModelOne)
  end

  let(:base) { described_class.new(obj_one) }
  subject { base }

  describe '#attributes' do
    subject { base.attributes }

    describe 'fields' do
      let(:obj_one) { ModelOne.new }
      let(:obj_one) { ModelOne.new(foo: 'Foo', bar: 'Bar') }
      it { is_expected.to eq('foo' => [nil, 'Foo']) }
    end

    describe '#insert_embeds_one_changes' do
      context 'when untracked relation' do
        before :each do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_twos

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end

            track_history on: :fields
          end

          class EmbOneOne
            include Mongoid::Document

            field :em_bar
            embedded_in :model_one
          end
        end

        after :each do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj) }
        let(:emb_obj) { EmbOneOne.new(em_bar: 'Em-Bar') }

        it { is_expected.to eq({}) }
      end

      context 'when tracked relation' do
        before :each do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_twos

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end

            track_history on: :emb_one_one
          end

          class EmbOneOne
            include Mongoid::Document

            field :em_bar
            embedded_in :model_one
          end
        end

        after :each do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj) }
        let(:emb_obj) { EmbOneOne.new(em_bar: 'Em-Bar') }

        it { is_expected.to eq('emb_one_one' => [nil, { '_id' => emb_obj._id, 'em_bar' => 'Em-Bar' }]) }
      end

      context 'when paranoia_field without alias' do
        before :each do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_twos

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end

            track_history on: :emb_one_one
          end

          class EmbOneOne
            include Mongoid::Document
            include Mongoid::History::Trackable

            field :em_bar
            field :removed_at

            embedded_in :model_one

            history_settings paranoia_field: :removed_at
          end
        end

        after :each do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj) }
        let(:emb_obj) { EmbOneOne.new(em_bar: 'Em-Bar', removed_at: Time.now) }

        it { is_expected.to eq({}) }
      end

      context 'when paranoia_field with alias' do
        before :each do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_twos

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end

            track_history on: :emb_one_one
          end

          class EmbOneOne
            include Mongoid::Document
            include Mongoid::History::Trackable

            field :em_bar
            field :rmvt, as: :removed_at

            embedded_in :model_one

            history_settings paranoia_field: :removed_at
          end
        end

        after :each do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj) }
        let(:emb_obj) { EmbOneOne.new(em_bar: 'Em-Bar', removed_at: Time.now) }

        it { is_expected.to eq({}) }
      end

      context 'with permitted attributes' do
        before :each do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_twos

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end

            track_history on: [{ emb_one_one: :em_bar }]
          end

          class EmbOneOne
            include Mongoid::Document
            include Mongoid::History::Trackable

            field :em_foo
            field :em_bar

            embedded_in :model_one
          end
        end

        after :each do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj) }
        let(:emb_obj) { EmbOneOne.new(em_foo: 'Em-Foo', em_bar: 'Em-Bar') }

        it { is_expected.to eq('emb_one_one' => [nil, { '_id' => emb_obj._id, 'em_bar' => 'Em-Bar' }]) }
      end

      context 'when relation with alias' do
        before :each do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_twos

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one, store_as: :eoo
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne', store_as: :eoo
            end

            track_history on: :emb_one_one
          end

          class EmbOneOne
            include Mongoid::Document

            field :em_bar
            embedded_in :model_one
          end
        end

        after :each do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj) }
        let(:emb_obj) { EmbOneOne.new(em_bar: 'Em-Bar') }

        it { is_expected.to eq('emb_one_one' => [nil, { '_id' => emb_obj._id, 'em_bar' => 'Em-Bar' }]) }
      end

      context 'when no object' do
        before :each do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_twos

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one, store_as: :eoo
            else
              embeds_one :emb_one_one, store_as: :eoo, inverse_class_name: 'EmbOneOne'
            end

            track_history on: :emb_one_one
          end

          class EmbOneOne
            include Mongoid::Document

            field :em_bar
            embedded_in :model_one
          end
        end

        after :each do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end

        let(:obj_one) { ModelTwo.new }

        it { is_expected.to eq({}) }
      end

      context 'when object not paranoid' do
        before :each do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_twos

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one, store_as: :eoo
            else
              embeds_one :emb_one_one, store_as: :eoo, inverse_class_name: 'EmbOneOne'
            end

            track_history on: :emb_one_one
          end

          class EmbOneOne
            include Mongoid::Document
            include Mongoid::History::Trackable

            field :em_bar
            field :cancelled_at

            embedded_in :model_one

            history_settings paranoia_field: :cancelled_at
          end
        end

        after :each do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj) }
        let(:emb_obj) { EmbOneOne.new(em_bar: 'Em-Bar') }

        it { is_expected.to eq('emb_one_one' => [nil, { '_id' => emb_obj._id, 'em_bar' => 'Em-Bar' }]) }
      end
    end

    pending '#insert_embeds_many_changes'
  end
end
