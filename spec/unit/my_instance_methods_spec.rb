require 'spec_helper'

describe Mongoid::History::Trackable do
  describe 'MyInstanceMethods' do
    before :all do
      ModelOne = Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        store_in collection: :model_ones
        field :foo
        field :b, as: :bar
        embeds_one :emb_one, inverse_class_name: 'EmbOne'
        embeds_one :emb_two, store_as: :emt, inverse_class_name: 'EmbTwo'
        embeds_many :emb_threes, inverse_class_name: 'EmbThree'
        embeds_many :emb_fours, store_as: :emfs, inverse_class_name: 'EmbFour'
      end

      EmbOne = Class.new do
        include Mongoid::Document
        field :f_em_foo
        field :fmb, as: :f_em_bar
        embedded_in :model_one
      end

      EmbTwo = Class.new do
        include Mongoid::Document
        field :baz
        embedded_in :model_one
      end

      EmbThree = Class.new do
        include Mongoid::Document
        field :f_em_foo
        field :fmb, as: :f_em_bar
        embedded_in :model_one
      end

      EmbFour = Class.new do
        include Mongoid::Document
        field :baz
        embedded_in :model_one
      end

      ModelOne.track_history(on: %i(foo emb_one emb_threes))
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }

    let(:bson_class) { defined?(BSON::ObjectId) ? BSON::ObjectId : Moped::BSON::ObjectId }

    let(:emb_one) { EmbOne.new(f_em_foo: 'Foo', f_em_bar: 'Bar') }
    let(:emb_threes) { [EmbThree.new(f_em_foo: 'Foo', f_em_bar: 'Bar')] }
    let(:model_one) do
      ModelOne.new(foo: 'Foo',
                   bar: 'Bar',
                   emb_one: emb_one,
                   emb_threes: emb_threes)
    end

    describe '#modified_attributes_for_create' do
      before(:each) { ModelOne.clear_trackable_memoization }
      subject { model_one.send(:modified_attributes_for_create) }

      context 'with tracked embeds_one object' do
        before(:each) { ModelOne.track_history(on: { emb_one: :f_em_foo }) }
        it 'should include tracked attributes only' do
          expect(subject['emb_one'][0]).to be_nil

          expect(subject['emb_one'][1].keys.size).to eq 2
          expect(subject['emb_one'][1]['_id']).to eq emb_one._id
          expect(subject['emb_one'][1]['f_em_foo']).to eq 'Foo'
        end
      end

      context 'with untracked embeds_one object' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it 'should not include embeds_one attributes' do
          expect(subject['emb_one']).to be_nil
        end
      end

      context 'with tracked embeds_many objects' do
        before(:each) { ModelOne.track_history(on: { emb_threes: :f_em_foo }) }
        it 'should include tracked attributes only' do
          expect(subject['emb_threes'][0]).to be_nil

          expect(subject['emb_threes'][1][0].keys.count).to eq 2
          expect(subject['emb_threes'][1][0]['_id']).to eq emb_threes.first._id
          expect(subject['emb_threes'][1][0]['f_em_foo']).to eq 'Foo'
        end
      end

      context 'with untracked embeds_many objects' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it 'should include not tracked embeds_many attributes' do
          expect(subject['emb_threes']).to be_nil
        end
      end
    end

    describe '#modified_attributes_for_update' do
      before(:each) do
        model_one.save!
        ModelOne.clear_trackable_memoization
        allow(model_one).to receive(:changes) { changes }
      end
      let(:changes) { {} }
      subject { model_one.send(:modified_attributes_for_update) }

      context 'when embeds_one attributes passed in options' do
        before(:each) { ModelOne.track_history(on: { emb_one: :f_em_foo }) }
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }, { 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }] } }
        it { expect(subject['emb_one'][0]).to eq('f_em_foo' => 'Foo') }
        it { expect(subject['emb_one'][1]).to eq('f_em_foo' => 'Foo-new') }
      end

      context 'when embeds_one relation passed in options' do
        before(:each) { ModelOne.track_history(on: :emb_one) }
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }, { 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }] } }
        it { expect(subject['emb_one'][0]).to eq('f_em_foo' => 'Foo', 'fmb' => 'Bar') }
        it { expect(subject['emb_one'][1]).to eq('f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new') }
      end

      context 'when embeds_one relation not tracked' do
        before(:each) { ModelOne.track_history(on: :fields) }
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo' }, { 'f_em_foo' => 'Foo-new' }] } }
        it { expect(subject['emb_one']).to be_nil }
      end

      context 'when embeds_many attributes passed in options' do
        before(:each) { ModelOne.track_history(on: { emb_threes: :f_em_foo }) }
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] } }
        it { expect(subject['emb_threes']).to eq [[{ 'f_em_foo' => 'Foo' }], [{ 'f_em_foo' => 'Foo-new' }]] }
      end

      context 'when embeds_many relation passed in options' do
        before(:each) { ModelOne.track_history(on: :emb_threes) }
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] } }
        it { expect(subject['emb_threes']).to eq [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] }
      end

      context 'when embeds_many relation not tracked' do
        before(:each) { ModelOne.track_history(on: :fields) }
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo' }], [{ 'f_em_foo' => 'Foo-new' }]] } }
        it { expect(subject['emb_threes']).to be_nil }
      end

      context 'when field tracked' do
        before(:each) { ModelOne.track_history(on: :foo) }
        let(:changes) { { 'foo' => ['Foo', 'Foo-new'], 'b' => ['Bar', 'Bar-new'] } }
        it { is_expected.to eq('foo' => ['Foo', 'Foo-new']) }
      end

      context 'when field not tracked' do
        before(:each) { ModelOne.track_history(on: []) }
        let(:changes) { { 'foo' => ['Foo', 'Foo-new'] } }
        it { is_expected.to eq({}) }
      end
    end

    describe '#modified_attributes_for_destroy' do
      before(:each) do
        model_one.save!
        ModelOne.clear_trackable_memoization
      end
      subject { model_one.send(:modified_attributes_for_destroy) }

      context 'with tracked embeds_one object' do
        before(:each) { ModelOne.track_history(on: { emb_one: :f_em_foo }) }
        it 'should include tracked attributes only' do
          expect(subject['emb_one'][0].keys.size).to eq 2
          expect(subject['emb_one'][0]['_id']).to eq emb_one._id
          expect(subject['emb_one'][0]['f_em_foo']).to eq 'Foo'

          expect(subject['emb_one'][1]).to be_nil
        end
      end

      context 'with untracked embeds_one object' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it 'should not include embeds_one attributes' do
          expect(subject['emb_one']).to be_nil
        end
      end

      context 'with tracked embeds_many objects' do
        before(:each) { ModelOne.track_history(on: { emb_threes: :f_em_foo }) }
        it 'should include tracked attributes only' do
          expect(subject['emb_threes'][0][0].keys.count).to eq 2
          expect(subject['emb_threes'][0][0]['_id']).to eq emb_threes.first._id
          expect(subject['emb_threes'][0][0]['f_em_foo']).to eq 'Foo'

          expect(subject['emb_threes'][1]).to be_nil
        end
      end

      context 'with untracked embeds_many objects' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it 'should include not tracked embeds_many attributes' do
          expect(subject['emb_threes']).to be_nil
        end
      end
    end

    after :all do
      Object.send(:remove_const, :ModelOne)
      Object.send(:remove_const, :EmbOne)
      Object.send(:remove_const, :EmbTwo)
      Object.send(:remove_const, :EmbThree)
      Object.send(:remove_const, :EmbFour)
    end
  end
end
