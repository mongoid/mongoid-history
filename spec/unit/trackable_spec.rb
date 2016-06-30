require 'spec_helper'

class MyModel
  include Mongoid::Document
  include Mongoid::History::Trackable
  field :foo
end

class MyDynamicModel
  include Mongoid::Document
  include Mongoid::History::Trackable
  include Mongoid::Attributes::Dynamic unless Mongoid::Compatibility::Version.mongoid3?
end

class HistoryTracker
  include Mongoid::History::Tracker
end

describe Mongoid::History::Trackable do
  let(:bson_class) { defined?(BSON::ObjectId) ? BSON::ObjectId : Moped::BSON::ObjectId }

  it 'should have #track_history' do
    expect(MyModel).to respond_to :track_history
  end

  it 'should append trackable_class_options ONLY when #track_history is called' do
    expect(Mongoid::History.trackable_class_options).to be_blank
    MyModel.track_history
    expect(Mongoid::History.trackable_class_options.keys).to eq([:my_model])
  end

  describe '#track_history' do
    before :all do
      MyModel.track_history
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }
    let(:expected_option) do
      { on: %i(foo),
        except: %w(created_at updated_at),
        tracker_class_name: nil,
        modifier_field: :modifier,
        version_field: :version,
        changes_method: :changes,
        scope: :my_model,
        track_create: false,
        track_update: true,
        track_destroy: false,
        fields: %w(foo),
        relations: { embeds_one: {}, embeds_many: {} },
        dynamic: [] }
    end
    let(:regular_fields) { ['foo'] }
    let(:reserved_fields) { %w(_id version modifier_id) }

    it 'should have default options' do
      expect(Mongoid::History.trackable_class_options[:my_model]).to eq(expected_option)
    end

    it 'should define callback function #track_update' do
      expect(MyModel.new.private_methods.collect(&:to_sym)).to include(:track_update)
    end

    it 'should define callback function #track_create' do
      expect(MyModel.new.private_methods.collect(&:to_sym)).to include(:track_create)
    end

    it 'should define callback function #track_destroy' do
      expect(MyModel.new.private_methods.collect(&:to_sym)).to include(:track_destroy)
    end

    it 'should define #history_trackable_options' do
      expect(MyModel.history_trackable_options).to eq(expected_option)
    end

    describe '#tracked_fields' do
      it 'should return the tracked field list' do
        expect(MyModel.tracked_fields).to eq(regular_fields)
      end
    end

    describe '#reserved_tracked_fields' do
      it 'should return the protected field list' do
        expect(MyModel.reserved_tracked_fields).to eq(reserved_fields)
      end
    end

    describe '#tracked_fields_for_action' do
      it 'should include the reserved fields for destroy' do
        expect(MyModel.tracked_fields_for_action(:destroy)).to eq(regular_fields + reserved_fields)
      end
      it 'should not include the reserved fields for update' do
        expect(MyModel.tracked_fields_for_action(:update)).to eq(regular_fields)
      end
      it 'should not include the reserved fields for create' do
        expect(MyModel.tracked_fields_for_action(:create)).to eq(regular_fields)
      end
    end

    describe '#tracked_field?' do
      it 'should not include the reserved fields by default' do
        expect(MyModel.tracked_field?(:_id)).to be false
      end
      it 'should include the reserved fields for destroy' do
        expect(MyModel.tracked_field?(:_id, :destroy)).to be true
      end
      it 'should allow field aliases' do
        expect(MyModel.tracked_field?(:id, :destroy)).to be true
      end

      context 'when model is dynamic' do
        it 'should allow dynamic fields tracking' do
          MyDynamicModel.track_history
          expect(MyDynamicModel.tracked_field?(:dynamic_field, :destroy)).to be true
        end
      end

      unless Mongoid::Compatibility::Version.mongoid3?
        context 'when model is not dynamic' do
          it 'should not allow dynamic fields tracking' do
            MyModel.track_history
            expect(MyModel.tracked_field?(:dynamic_field, :destroy)).to be false
          end
        end
      end

      it 'allows a non-database field to be specified' do
        class MyNonDatabaseModel
          include Mongoid::Document
          include Mongoid::History::Trackable
          track_history on: ['baz']
        end

        expect(MyNonDatabaseModel.tracked_field?(:baz)).to be true
      end
    end

    context '#dynamic_field?' do
      context 'when model is dynamic' do
        it 'should return true' do
          MyDynamicModel.track_history
          expect(MyDynamicModel.dynamic_field?(:dynamic_field)).to be true
        end
      end

      unless Mongoid::Compatibility::Version.mongoid3?
        context 'when model is not dynamic' do
          it 'should return false' do
            MyModel.track_history
            expect(MyModel.dynamic_field?(:dynamic_field)).to be false
          end
        end
      end
    end

    context 'sub-model' do
      before :each do
        class MySubModel < MyModel
        end
      end

      it 'should have default options' do
        expect(Mongoid::History.trackable_class_options[:my_model]).to eq(expected_option)
      end

      it 'should define #history_trackable_options' do
        expect(MySubModel.history_trackable_options).to eq(expected_option)
      end
    end

    describe '#track_history?' do
      context 'when tracking is globally enabled' do
        it 'should be enabled on the current thread' do
          expect(Mongoid::History.enabled?).to eq(true)
          expect(MyModel.new.track_history?).to eq(true)
        end

        it 'should be disabled within disable_tracking' do
          MyModel.disable_tracking do
            expect(Mongoid::History.enabled?).to eq(true)
            expect(MyModel.new.track_history?).to eq(false)
          end
        end

        it 'should be rescued if an exception occurs' do
          begin
            MyModel.disable_tracking do
              fail 'exception'
            end
          rescue
          end
          expect(Mongoid::History.enabled?).to eq(true)
          expect(MyModel.new.track_history?).to eq(true)
        end

        it 'should be disabled only for the class that calls disable_tracking' do
          class MyModel2
            include Mongoid::Document
            include Mongoid::History::Trackable
            track_history
          end

          MyModel.disable_tracking do
            expect(Mongoid::History.enabled?).to eq(true)
            expect(MyModel2.new.track_history?).to eq(true)
          end
        end
      end

      context 'when tracking is globally disabled' do
        around(:each) do |example|
          Mongoid::History.disable do
            example.run
          end
        end

        it 'should be disabled by the global disablement' do
          expect(Mongoid::History.enabled?).to eq(false)
          expect(MyModel.new.track_history?).to eq(false)
        end

        it 'should be disabled within disable_tracking' do
          MyModel.disable_tracking do
            expect(Mongoid::History.enabled?).to eq(false)
            expect(MyModel.new.track_history?).to eq(false)
          end
        end

        it 'should be rescued if an exception occurs' do
          begin
            MyModel.disable_tracking do
              fail 'exception'
            end
          rescue
          end
          expect(Mongoid::History.enabled?).to eq(false)
          expect(MyModel.new.track_history?).to eq(false)
        end

        it 'should be disabled only for the class that calls disable_tracking' do
          class MyModel2
            include Mongoid::Document
            include Mongoid::History::Trackable
            track_history
          end

          MyModel.disable_tracking do
            expect(Mongoid::History.enabled?).to eq(false)
            expect(MyModel2.new.track_history?).to eq(false)
          end
        end
      end

      it 'should rescue errors through both local and global tracking scopes' do
        begin
          Mongoid::History.disable do
            MyModel.disable_tracking do
              fail 'exception'
            end
          end
        rescue
        end
        expect(Mongoid::History.enabled?).to eq(true)
        expect(MyModel.new.track_history?).to eq(true)
      end
    end

    describe ':changes_method' do
      it 'should default to :changes' do
        m = MyModel.create
        expect(m).to receive(:changes).exactly(3).times.and_call_original
        expect(m).not_to receive(:my_changes)
        m.save
      end

      it 'should allow an alternate method to be specified' do
        class MyModel3 < MyModel
          track_history changes_method: :my_changes

          def my_changes
            {}
          end
        end

        m = MyModel3.create
        expect(m).to receive(:changes).twice.and_call_original
        expect(m).to receive(:my_changes).once.and_call_original
        m.save
      end
    end
  end

  describe '#tracker_class' do
    before :all do
      MyTrackerClass = Class.new
    end

    before { MyModel.instance_variable_set(:@history_trackable_options, nil) }

    context 'when options contain tracker_class_name' do
      context 'when underscored' do
        before { MyModel.track_history tracker_class_name: 'my_tracker_class' }
        it { expect(MyModel.tracker_class).to eq MyTrackerClass }
      end

      context 'when camelcased' do
        before { MyModel.track_history tracker_class_name: 'MyTrackerClass' }
        it { expect(MyModel.tracker_class).to eq MyTrackerClass }
      end

      context 'when constant' do
        before { MyModel.track_history tracker_class_name: MyTrackerClass }
        it { expect(MyModel.tracker_class).to eq MyTrackerClass }
      end
    end

    context 'when options not contain tracker_class_name' do
      before { MyModel.track_history }
      it { expect(MyModel.tracker_class).to eq Tracker }
    end

    after :all do
      Object.send(:remove_const, :MyTrackerClass)
    end
  end

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

  describe 'SingletonMethods' do
    before :all do
      MyTrackableModel = Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        field :foo
        field :b, as: :bar
        embeds_one :my_embed_one_model, inverse_class_name: 'MyEmbedOneModel'
        embeds_one :my_untracked_embed_one_model, inverse_class_name: 'MyUntrackedEmbedOneModel'
        embeds_many :my_embed_many_models, inverse_class_name: 'MyEmbedManyModel'
      end

      MyEmbedOneModel = Class.new do
        include Mongoid::Document
        field :baz
        embedded_in :my_trackable_model
      end

      MyUntrackedEmbedOneModel = Class.new do
        include Mongoid::Document
        field :baz
        embedded_in :my_trackable_model
      end

      MyEmbedManyModel = Class.new do
        include Mongoid::Document
        field :bla
        embedded_in :my_trackable_model
      end

      MyTrackableModel.track_history(on: [:foo, :my_embed_one_model, :my_embed_many_models, :my_dynamic_field])
    end

    describe '#tracked?' do
      before { allow(MyTrackableModel).to receive(:dynamic_enabled?) { false } }
      it { expect(MyTrackableModel.tracked?(:foo)).to be true }
      it { expect(MyTrackableModel.tracked?(:bar)).to be false }
      it { expect(MyTrackableModel.tracked?(:my_embed_one_model)).to be true }
      it { expect(MyTrackableModel.tracked?(:my_untracked_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked?(:my_embed_many_models)).to be true }
      it { expect(MyTrackableModel.tracked?(:my_dynamic_field)).to be true }
    end

    describe '#tracked_fields' do
      it 'should include fields and dynamic fields' do
        expect(MyTrackableModel.tracked_fields).to eq %w(foo my_dynamic_field)
      end
    end

    describe '#tracked_relation?' do
      it 'should return true if a relation is tracked' do
        expect(MyTrackableModel.tracked_relation?(:my_embed_one_model)).to be true
        expect(MyTrackableModel.tracked_relation?(:my_untracked_embed_one_model)).to be false
        expect(MyTrackableModel.tracked_relation?(:my_embed_many_models)).to be true
      end
    end

    describe '#tracked_embeds_one?' do
      it { expect(MyTrackableModel.tracked_embeds_one?(:my_embed_one_model)).to be true }
      it { expect(MyTrackableModel.tracked_embeds_one?(:my_untracked_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embeds_one?(:my_embed_many_models)).to be false }
    end

    describe '#tracked_embeds_one' do
      it { expect(MyTrackableModel.tracked_embeds_one).to include 'my_embed_one_model' }
      it { expect(MyTrackableModel.tracked_embeds_one).to_not include 'my_untracked_embed_one_model' }
    end

    describe '#tracked_embeds_many?' do
      it { expect(MyTrackableModel.tracked_embeds_many?(:my_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embeds_many?(:my_untracked_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embeds_many?(:my_embed_many_models)).to be true }
    end

    describe '#tracked_embeds_many' do
      it { expect(MyTrackableModel.tracked_embeds_many).to eq ['my_embed_many_models'] }
    end

    describe '#clear_trackable_memoization' do
      before do
        MyTrackableModel.instance_variable_set(:@reserved_tracked_fields, %w(_id _type))
        MyTrackableModel.instance_variable_set(:@history_trackable_options, on: %w(fields))
        MyTrackableModel.instance_variable_set(:@tracked_fields, %w(foo))
        MyTrackableModel.instance_variable_set(:@tracked_embeds_one, %w(my_embed_one_model))
        MyTrackableModel.instance_variable_set(:@tracked_embeds_many, %w(my_embed_many_models))
        MyTrackableModel.clear_trackable_memoization
      end

      it 'should clear all the trackable memoization' do
        expect(MyTrackableModel.instance_variable_get(:@reserved_tracked_fields)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@history_trackable_options)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@tracked_fields)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@tracked_embeds_one)).to be_nil
        expect(MyTrackableModel.instance_variable_get(:@tracked_embeds_many)).to be_nil
      end
    end

    after :all do
      Object.send(:remove_const, :MyTrackableModel)
      Object.send(:remove_const, :MyEmbedOneModel)
      Object.send(:remove_const, :MyUntrackedEmbedOneModel)
      Object.send(:remove_const, :MyEmbedManyModel)
    end
  end
end
