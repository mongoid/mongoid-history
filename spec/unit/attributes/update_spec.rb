require 'spec_helper'

describe Mongoid::History::Attributes::Update do
  describe '#attributes' do
    describe '#insert_embeds_one_changes' do
      context 'Case: relation without alias' do
        before :each do
          class ModelOne
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_ones
            embeds_one :emb_one

            track_history on: :fields
          end

          class EmbOne
            include Mongoid::Document

            field :em_foo
            field :em_bar

            embedded_in :model_one
          end
        end

        after :each do
          Object.send(:remove_const, :ModelOne)
          Object.send(:remove_const, :EmbOne)
        end

        before :each do
          allow(base).to receive(:changes) { changes }
        end

        let(:obj_one) { ModelOne.new }
        let(:base) { described_class.new(obj_one) }
        let(:changes) do
          { 'emb_one' => [{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
        end
        subject { base.attributes }

        context 'with permitted attributes' do
          before :each do
            ModelOne.track_history on: { emb_one: :em_foo }
          end
          it { expect(subject['emb_one']).to eq [{ 'em_foo' => 'Em-Foo' }, { 'em_foo' => 'Em-Foo-new' }] }
        end

        context 'without permitted attributes' do
          before :each do
            ModelOne.track_history on: :emb_one
          end
          it { expect(subject['emb_one']).to eq [{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
        end

        context 'when old value soft-deleted' do
          before :each do
            ModelOne.track_history on: :emb_one
          end
          let(:changes) do
            { 'emb_one' => [{ 'em_foo' => 'Em-Foo', 'deleted_at' => Time.now }, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
          end
          it { expect(subject['emb_one']).to eq [{}, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
        end

        context 'when new value soft-deleted' do
          before :each do
            ModelOne.track_history on: :emb_one
          end
          let(:changes) do
            { 'emb_one' => [{ 'em_foo' => 'Em-Foo' }, { 'em_foo' => 'Em-Foo-new', 'deleted_at' => Time.now }] }
          end
          it { expect(subject['emb_one']).to eq [{ 'em_foo' => 'Em-Foo' }, {}] }
        end

        context 'when not tracked' do
          before :each do
            ModelOne.track_history on: :fields
            allow(ModelOne).to receive(:dynamic_enabled?) { false }
          end
          it { expect(subject['emb_one']).to be_nil }
        end
      end

      context 'Case: relation with alias' do
        before :each do
          class ModelOne
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_ones
            embeds_one :emb_one, store_as: :eon
            track_history on: :fields
          end

          class EmbOne
            include Mongoid::Document
            field :em_foo
            field :em_bar
            embedded_in :model_one
          end
        end

        after :each do
          Object.send(:remove_const, :ModelOne)
          Object.send(:remove_const, :EmbOne)
        end

        before :each do
          ModelOne.track_history on: :emb_one
          allow(base).to receive(:changes) { changes }
        end

        let(:obj_one) { ModelOne.new }
        let(:base) { described_class.new(obj_one) }
        let(:changes) do
          { 'emb_one' => [{ 'em_foo' => 'Em-Foo' }, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
        end
        subject { base.attributes }
        it { expect(subject['eon']).to eq [{ 'em_foo' => 'Em-Foo' }, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
      end

      context 'when original and modified value same' do
        before :each do
          class DummyUpdateModel
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :dummy_update_models
            embeds_one :dummy_embedded_model
            track_history on: :fields
          end

          class DummyEmbeddedModel
            include Mongoid::Document
            field :em_foo
            field :em_bar
            embedded_in :dummy_update_model
          end
        end

        after :each do
          Object.send(:remove_const, :DummyUpdateModel)
          Object.send(:remove_const, :DummyEmbeddedModel)
        end

        before :each do
          allow(base).to receive(:changes) { changes }
          DummyUpdateModel.track_history on: :dummy_embedded_model
        end

        let(:obj_one) { DummyUpdateModel.new }
        let(:base) { described_class.new(obj_one) }
        let(:changes) do
          { 'dummy_embedded_model' => [{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }, { 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }] }
        end
        subject { base.attributes }
        it { expect(subject.keys).to_not include 'dummy_embedded_model' }
      end
    end

    describe '#insert_embeds_many_changes' do
      context 'Case: relation without alias' do
        before :each do
          class ModelOne
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_ones
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_many :emb_ones
            else
              embeds_many :emb_ones, inverse_class_name: 'EmbOne'
            end
            track_history on: :fields
          end

          class EmbOne
            include Mongoid::Document
            field :em_foo
            field :em_bar
            embedded_in :model_one
          end
        end

        before :each do
          allow(base).to receive(:changes) { changes }
        end

        let(:obj_one) { ModelOne.new }
        let(:base) { described_class.new(obj_one) }
        subject { base.attributes }

        context 'with whitelist attributes' do
          before :each do
            ModelOne.track_history on: { emb_ones: :em_foo }
          end
          let(:changes) do
            { 'emb_ones' => [[{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }], [{ 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }]] }
          end
          it 'should track only whitelisted attributes' do
            expect(subject['emb_ones']).to eq [[{ 'em_foo' => 'Em-Foo' }], [{ 'em_foo' => 'Em-Foo-new' }]]
          end
        end

        context 'without whitelist attributes' do
          before :each do
            ModelOne.track_history(on: :emb_ones)
          end
          let(:changes) do
            { 'emb_ones' => [[{ 'em_foo' => 'Em-Foo', 'deleted_at' => Time.now }], [{ 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }]] }
          end
          it 'should ignore soft-deleted objects' do
            expect(subject['emb_ones']).to eq [[], [{ 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }]]
          end
        end

        after :each do
          Object.send(:remove_const, :ModelOne)
          Object.send(:remove_const, :EmbOne)
        end
      end

      context 'Case: relation with alias' do
        before :each do
          class ModelOne
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_ones
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_many :emb_ones, store_as: :eons
            else
              embeds_many :emb_ones, store_as: :eons, inverse_class_name: 'EmbOne'
            end
            track_history on: :fields
          end

          class EmbOne
            include Mongoid::Document
            field :em_foo
            field :em_bar
            embedded_in :model_one
          end
        end

        before :each do
          ModelOne.track_history on: :emb_ones
          allow(base).to receive(:changes) { changes }
        end

        let(:obj_one) { ModelOne.new }
        let(:base) { described_class.new(obj_one) }
        let(:changes) do
          { 'emb_ones' => [[{ 'em_foo' => 'Em-Foo' }], [{ 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }]] }
        end
        subject { base.attributes }
        it 'should save audit history under relation alias' do
          expect(subject['eons']).to eq [[{ 'em_foo' => 'Em-Foo' }], [{ 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }]]
        end

        after :each do
          Object.send(:remove_const, :ModelOne)
          Object.send(:remove_const, :EmbOne)
        end
      end

      context 'when original and modified value same' do
        before :each do
          class ModelOne
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_ones
            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_many :emb_ones
            else
              embeds_many :emb_ones, inverse_class_name: 'EmbOne'
            end
            track_history on: :fields
          end

          class EmbOne
            include Mongoid::Document
            field :em_foo
            field :em_bar
            embedded_in :model_one
          end
        end

        before :each do
          allow(base).to receive(:changes) { changes }
          ModelOne.track_history on: :emb_ones
        end

        let(:obj_one) { ModelOne.new }
        let(:base) { described_class.new(obj_one) }
        let(:changes) do
          { 'emb_ones' => [[{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }], [{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }]] }
        end
        subject { base.attributes }
        it { expect(subject.keys).to_not include 'emb_ones' }

        after :each do
          Object.send(:remove_const, :ModelOne)
          Object.send(:remove_const, :EmbOne)
        end
      end
    end

    context 'when original and modified values blank' do
      before :each do
        class DummyParent
          include Mongoid::Document
          include Mongoid::History::Trackable
          store_in collection: :dummy_parents
          has_and_belongs_to_many :other_dummy_parents
          track_history on: :fields
        end

        class OtherDummyParent
          include Mongoid::Document
          has_and_belongs_to_many :dummy_parents
        end
      end

      before :each do
        allow(base).to receive(:changes) { changes }
        DummyParent.track_history on: :other_dummy_parent_ids
      end

      let(:base) { described_class.new(DummyParent.new) }
      let(:changes) do
        { 'other_dummy_parent_ids' => [nil, []] }
      end
      subject { base.attributes }
      it { expect(subject.keys).to_not include 'other_dummy_parent_ids' }

      after :each do
        Object.send(:remove_const, :DummyParent)
        Object.send(:remove_const, :OtherDummyParent)
      end
    end
  end
end
