require 'spec_helper'

describe Mongoid::History::Attributes::Create do
  let(:model_one) do
    Class.new do
      include Mongoid::Document
      include Mongoid::History::Trackable
      store_in collection: :model_ones
      field :foo
      field :b, as: :bar
      def self.name
        'ModelOne'
      end
    end
  end

  let(:obj_one) { model_one.new }
  let(:base) { described_class.new(obj_one) }
  subject { base }

  describe '#attributes' do
    subject { base.attributes }

    describe 'fields' do
      before(:each) do
        model_one.instance_variable_set(:@history_trackable_options, nil)
        model_one.track_history on: :foo
      end
      let(:obj_one) { model_one.new(foo: 'Foo', bar: 'Bar') }
      it { is_expected.to eq('foo' => [nil, 'Foo']) }
    end

    describe '#insert_embeds_one_changes' do
      context 'when untracked relation' do
        before(:all) do
          # Need class name constant
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_twos
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end
          end

          class EmbOneOne
            include Mongoid::Document
            field :em_bar
            embedded_in :model_one
          end
        end

        before(:each) do
          ModelTwo.instance_variable_set(:@history_trackable_options, nil)
          ModelTwo.track_history on: :fields
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj_one) }
        let(:emb_obj_one) { EmbOneOne.new(em_bar: 'Em-Bar') }

        it { is_expected.to eq({}) }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end
      end

      context 'when tracked relation' do
        before(:all) do
          # Need class name constant
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_twos
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end
          end

          class EmbOneOne
            include Mongoid::Document
            field :em_bar
            embedded_in :model_one
          end
        end

        before(:each) do
          ModelTwo.instance_variable_set(:@history_trackable_options, nil)
          ModelTwo.track_history on: :emb_one_one
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj_one) }
        let(:emb_obj_one) { EmbOneOne.new(em_bar: 'Em-Bar') }

        it { is_expected.to eq('emb_one_one' => [nil, { '_id' => emb_obj_one._id, 'em_bar' => 'Em-Bar' }]) }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end
      end

      context 'when paranoia_field without alias' do
        before(:all) do
          # Need class name constant
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_twos
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end
          end

          class EmbOneOne
            include Mongoid::Document
            include Mongoid::History::Trackable
            field :em_bar
            field :removed_at
            embedded_in :model_one
          end
        end

        before(:each) do
          ModelTwo.instance_variable_set(:@history_trackable_options, nil)
          EmbOneOne.instance_variable_set(:@rackable_settings, nil)
          ModelTwo.track_history on: :emb_one_one
          EmbOneOne.history_settings paranoia_field: :removed_at
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj_one) }
        let(:emb_obj_one) { EmbOneOne.new(em_bar: 'Em-Bar', removed_at: Time.now) }

        it { is_expected.to eq({}) }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end
      end

      context 'when paranoia_field with alias' do
        before(:all) do
          # Need class name constant
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_twos
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end
          end

          class EmbOneOne
            include Mongoid::Document
            include Mongoid::History::Trackable
            field :em_bar
            field :rmvt, as: :removed_at
            embedded_in :model_one
          end
        end

        before(:each) do
          ModelTwo.instance_variable_set(:@history_trackable_options, nil)
          EmbOneOne.instance_variable_set(:@rackable_settings, nil)
          ModelTwo.track_history on: :emb_one_one
          EmbOneOne.history_settings paranoia_field: :removed_at
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj_one) }
        let(:emb_obj_one) { EmbOneOne.new(em_bar: 'Em-Bar', removed_at: Time.now) }

        it { is_expected.to eq({}) }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end
      end

      context 'with permitted attributes' do
        before(:all) do
          # Need class name constant
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_twos
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne'
            end
          end

          class EmbOneOne
            include Mongoid::Document
            include Mongoid::History::Trackable
            field :em_foo
            field :em_bar
            embedded_in :model_one
          end
        end

        before(:each) do
          ModelTwo.instance_variable_set(:@history_trackable_options, nil)
          ModelTwo.track_history on: [{ emb_one_one: :em_bar }]
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj_one) }
        let(:emb_obj_one) { EmbOneOne.new(em_foo: 'Em-Foo', em_bar: 'Em-Bar') }

        it { is_expected.to eq('emb_one_one' => [nil, { '_id' => emb_obj_one._id, 'em_bar' => 'Em-Bar' }]) }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end
      end

      context 'when relation with alias' do
        before(:all) do
          # Need class name constant
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_twos
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one, store_as: :eoo
            else
              embeds_one :emb_one_one, inverse_class_name: 'EmbOneOne', store_as: :eoo
            end
          end

          class EmbOneOne
            include Mongoid::Document
            field :em_bar
            embedded_in :model_one
          end
        end

        before(:each) do
          ModelTwo.instance_variable_set(:@history_trackable_options, nil)
          ModelTwo.track_history on: :emb_one_one
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj_one) }
        let(:emb_obj_one) { EmbOneOne.new(em_bar: 'Em-Bar') }

        it { is_expected.to eq('emb_one_one' => [nil, { '_id' => emb_obj_one._id, 'em_bar' => 'Em-Bar' }]) }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end
      end

      context 'when no object' do
        before(:all) do
          # Need class name constant
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_twos
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one, store_as: :eoo
            else
              embeds_one :emb_one_one, store_as: :eoo, inverse_class_name: 'EmbOneOne'
            end
          end

          class EmbOneOne
            include Mongoid::Document
            field :em_bar
            embedded_in :model_one
          end
        end

        before(:each) do
          ModelTwo.instance_variable_set(:@history_trackable_options, nil)
          ModelTwo.track_history on: :emb_one_one
        end

        let(:obj_one) { ModelTwo.new }

        it { is_expected.to eq({}) }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end
      end

      context 'when object not paranoid' do
        before(:all) do
          # Need class name constant
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_twos
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :emb_one_one, store_as: :eoo
            else
              embeds_one :emb_one_one, store_as: :eoo, inverse_class_name: 'EmbOneOne'
            end
          end

          class EmbOneOne
            include Mongoid::Document
            include Mongoid::History::Trackable
            field :em_bar
            field :cancelled_at
            embedded_in :model_one
          end
        end

        before(:each) do
          ModelTwo.instance_variable_set(:@history_trackable_options, nil)
          EmbOneOne.instance_variable_set(:@trackable_settings, nil)
          ModelTwo.track_history on: :emb_one_one
          EmbOneOne.history_settings paranoia_field: :cancelled_at
        end

        let(:obj_one) { ModelTwo.new(emb_one_one: emb_obj_one) }
        let(:emb_obj_one) { EmbOneOne.new(em_bar: 'Em-Bar') }

        it { is_expected.to eq('emb_one_one' => [nil, { '_id' => emb_obj_one._id, 'em_bar' => 'Em-Bar' }]) }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmbOneOne)
        end
      end
    end

    describe '#insert_embeds_many_changes' do
    end
  end
end
