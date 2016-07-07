require 'spec_helper'

describe Mongoid::History::Attributes::Update do
  describe '#attributes' do
    describe '#insert_embeds_one_changes' do
      before(:all) do
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

      before(:each) do
        ModelOne.clear_trackable_memoization
        allow(base).to receive(:changes) { changes }
      end

      let(:obj_one) { ModelOne.new }
      let(:base) { described_class.new(obj_one) }
      let(:changes) do
        { 'emb_one' => [{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
      end
      subject { base.attributes }

      context 'with permitted attributes' do
        before(:each) { ModelOne.track_history on: { emb_one: :em_foo } }
        it { expect(subject['emb_one']).to eq [{ 'em_foo' => 'Em-Foo' }, { 'em_foo' => 'Em-Foo-new' }] }
      end

      context 'without permitted attributes' do
        before(:each) { ModelOne.track_history on: :emb_one }
        it { expect(subject['emb_one']).to eq [{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
      end

      context 'when old value soft-deleted' do
        before(:each) { ModelOne.track_history on: :emb_one }
        let(:changes) do
          { 'emb_one' => [{ 'em_foo' => 'Em-Foo', 'deleted_at' => Time.now }, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
        end
        it { expect(subject['emb_one']).to eq [{}, { 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }] }
      end

      context 'when new value soft-deleted' do
        before(:each) { ModelOne.track_history on: :emb_one }
        let(:changes) do
          { 'emb_one' => [{ 'em_foo' => 'Em-Foo' }, { 'em_foo' => 'Em-Foo-new', 'deleted_at' => Time.now }] }
        end
        it { expect(subject['emb_one']).to eq [{ 'em_foo' => 'Em-Foo' }, {}] }
      end

      context 'when not tracked' do
        before(:each) do
          ModelOne.track_history on: :fields
          allow(ModelOne).to receive(:dynamic_enabled?) { false }
        end
        it { expect(subject['emb_one']).to be_nil }
      end

      after(:all) do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
      end
    end

    describe '#insert_embeds_many_changes' do
      before(:all) do
        class ModelOne
          include Mongoid::Document
          include Mongoid::History::Trackable
          store_in collection: :model_ones
          embeds_many :emb_ones
          track_history on: :fields
        end

        class EmbOne
          include Mongoid::Document
          field :em_foo
          field :em_bar
          embedded_in :model_one
        end
      end

      before(:each) do
        ModelOne.clear_trackable_memoization
        allow(base).to receive(:changes) { changes }
      end

      let(:obj_one) { ModelOne.new }
      let(:base) { described_class.new(obj_one) }
      subject { base.attributes }

      context 'with whitelist attributes' do
        before(:each) { ModelOne.track_history on: { emb_ones: :em_foo } }
        let(:changes) do
          { 'emb_ones' => [[{ 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }], [{ 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }]] }
        end
        it 'should track only whitelisted attributes' do
          expect(subject['emb_ones']).to eq [[{ 'em_foo' => 'Em-Foo' }], [{ 'em_foo' => 'Em-Foo-new' }]]
        end
      end

      context 'without whitelist attributes' do
        before(:each) { ModelOne.track_history on: :emb_ones }
        let(:changes) do
          { 'emb_ones' => [[{ 'em_foo' => 'Em-Foo', 'deleted_at' => Time.now }], [{ 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }]] }
        end
        it 'should ignore soft-deleted objects' do
          expect(subject['emb_ones']).to eq [[], [{ 'em_foo' => 'Em-Foo-new', 'em_bar' => 'Em-Bar-new' }]]
        end
      end

      after(:all) do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
      end
    end
  end
end
