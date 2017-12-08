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
  it 'should have #track_history' do
    expect(MyModel).to respond_to :track_history
  end

  it 'should append trackable_class_options ONLY when #track_history is called' do
    expect(Mongoid::History.trackable_class_options).to be_blank
    MyModel.track_history
    expect(Mongoid::History.trackable_class_options.keys).to eq([:my_model])
  end

  describe '#track_history' do
    class MyModelWithNoModifier
      include Mongoid::Document
      include Mongoid::History::Trackable
      field :foo
    end

    before :all do
      MyModel.track_history
      @persisted_history_options = Mongoid::History.trackable_class_options
      MyModelWithNoModifier.track_history modifier_field: nil
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }
    let(:expected_option) do
      { on: %i[foo],
        except: %w[created_at updated_at],
        tracker_class_name: nil,
        modifier_field: :modifier,
        version_field: :version,
        changes_method: :changes,
        scope: :my_model,
        track_create: true,
        track_update: true,
        track_destroy: true,
        fields: %w[foo],
        relations: { embeds_one: {}, embeds_many: {} },
        dynamic: [],
        format: {} }
    end
    let(:regular_fields) { ['foo'] }
    let(:reserved_fields) { %w[_id version modifier_id] }

    it 'should have default options' do
      expect(Mongoid::History.trackable_class_options[:my_model].prepared).to eq(expected_option)
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

    describe '#modifier' do
      context 'modifier_field set to nil' do
        it 'should not have a modifier relationship' do
          expect(MyModelWithNoModifier.reflect_on_association(:modifier)).to be_nil
        end
      end

      context 'modifier_field_optional true' do
        class MyModelWithOptionalModifier
          include Mongoid::Document
          include Mongoid::History::Trackable
          field :foo
        end

        it 'marks modifier relationship optional' do
          MyModelWithOptionalModifier.track_history modifier_field_optional: true
          if Mongoid::Compatibility::Version.mongoid6_or_newer?
            expect(MyModelWithOptionalModifier.reflect_on_association(:modifier)[:optional]).to be true
          else
            expect(MyModelWithOptionalModifier.reflect_on_association(:modifier)).not_to be_nil
          end
        end
      end
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

      it 'should not include modifier_field if not specified' do
        expect(MyModelWithNoModifier.reserved_tracked_fields).not_to include('modifier')
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

    describe '#field_format' do
      before :all do
        ModelOne = Class.new do
          include Mongoid::Document
          include Mongoid::History::Trackable
          field :foo
        end
      end

      let(:format) { '***' }

      before do
        ModelOne.track_history format: { foo: format }
      end

      context 'when field is formatted' do
        it 'should return the format' do
          expect(ModelOne.field_format(:foo)).to be format
        end
      end

      context 'when field is not formatted' do
        it 'should return nil' do
          expect(ModelOne.field_format(:bar)).to be_nil
        end
      end

      after :all do
        Object.send(:remove_const, :ModelOne)
      end
    end

    context 'sub-model' do
      before :each do
        class MySubModel < MyModel
        end
      end

      it 'should have default options' do
        expect(Mongoid::History.trackable_class_options[:my_model].prepared).to eq(expected_option)
      end

      it 'should define #history_trackable_options' do
        expect(MySubModel.history_trackable_options).to eq(expected_option)
      end
    end

    describe '#track_history?' do
      shared_examples_for 'history tracking' do
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
                raise 'exception'
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
          it 'should be disabled by the global disablement' do
            Mongoid::History.disable do
              expect(Mongoid::History.enabled?).to eq(false)
              expect(MyModel.new.track_history?).to eq(false)
            end
          end

          it 'should be disabled within disable_tracking' do
            Mongoid::History.disable do
              MyModel.disable_tracking do
                expect(Mongoid::History.enabled?).to eq(false)
                expect(MyModel.new.track_history?).to eq(false)
              end
            end
          end

          it 'should be rescued if an exception occurs' do
            Mongoid::History.disable do
              begin
                MyModel.disable_tracking do
                  raise 'exception'
                end
              rescue
              end
              expect(Mongoid::History.enabled?).to eq(false)
              expect(MyModel.new.track_history?).to eq(false)
            end
          end

          it 'should be disabled only for the class that calls disable_tracking' do
            class MyModel2
              include Mongoid::Document
              include Mongoid::History::Trackable
              track_history
            end

            Mongoid::History.disable do
              MyModel.disable_tracking do
                expect(Mongoid::History.enabled?).to eq(false)
                expect(MyModel2.new.track_history?).to eq(false)
              end
            end
          end
        end

        it 'should rescue errors through both local and global tracking scopes' do
          begin
            Mongoid::History.disable do
              MyModel.disable_tracking do
                raise 'exception'
              end
            end
          rescue
          end
          expect(Mongoid::History.enabled?).to eq(true)
          expect(MyModel.new.track_history?).to eq(true)
        end
      end

      context 'when store is Thread' do
        it_behaves_like 'history tracking'
      end

      context 'when store is RequestStore' do
        before { stub_const('RequestStore', RequestStoreTemp) }
        it_behaves_like 'history tracking'
      end
    end

    describe ':changes_method' do
      let(:custom_tracker) do
        CustomTracker = Class.new(MyModel) do
          field :key

          track_history on: :key, changes_method: :my_changes, track_create: true

          def my_changes
            changes.merge('key' => "Save history-#{key}")
          end
        end
      end

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

      it 'should allow an alternate method to be specified on object creation' do
        m = custom_tracker.create(key: 'on object creation')
        history_track = m.history_tracks.last
        expect(history_track.modified['key']).to eq('Save history-on object creation')
      end
    end
  end

  describe '#history_settings' do
    before(:each) { Mongoid::History.trackable_settings = nil }

    let(:model_one) do
      Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        store_in collection: :model_ones
        embeds_one :emb_one, inverse_class_name: 'EmbOne'
        embeds_many :emb_twos, inverse_class_name: 'EmbTwo'

        def self.name
          'ModelOne'
        end
      end
    end

    let(:emb_one) do
      Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        embedded_in :model_one

        def self.name
          'EmbOne'
        end
      end
    end

    let(:emb_two) do
      Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        embedded_in :model_one

        def self.name
          'EmbTwo'
        end
      end
    end

    let(:default_options) { { paranoia_field: 'deleted_at' } }

    context 'when options not passed' do
      before(:each) do
        model_one.history_settings
        emb_one.history_settings
        emb_two.history_settings
      end

      it 'should use default options' do
        expect(Mongoid::History.trackable_settings[:ModelOne]).to eq(default_options)
        expect(Mongoid::History.trackable_settings[:EmbOne]).to eq(default_options)
        expect(Mongoid::History.trackable_settings[:EmbTwo]).to eq(default_options)
      end
    end

    context 'when extra invalid options passed' do
      before(:each) do
        model_one.history_settings foo: :bar
        emb_one.history_settings em_foo: :em_bar
        emb_two.history_settings em_foo: :em_baz
      end

      it 'should ignore invalid options' do
        expect(Mongoid::History.trackable_settings[:ModelOne]).to eq(default_options)
        expect(Mongoid::History.trackable_settings[:EmbOne]).to eq(default_options)
        expect(Mongoid::History.trackable_settings[:EmbTwo]).to eq(default_options)
      end
    end

    context 'when valid options passed' do
      before(:each) do
        model_one.history_settings paranoia_field: :disabled_at
        emb_one.history_settings paranoia_field: :deactivated_at
        emb_two.history_settings paranoia_field: :omitted_at
      end

      it 'should override default options' do
        expect(Mongoid::History.trackable_settings[:ModelOne]).to eq(paranoia_field: 'disabled_at')
        expect(Mongoid::History.trackable_settings[:EmbOne]).to eq(paranoia_field: 'deactivated_at')
        expect(Mongoid::History.trackable_settings[:EmbTwo]).to eq(paranoia_field: 'omitted_at')
      end
    end

    context 'when string keys' do
      before(:each) { model_one.history_settings 'paranoia_field' => 'erased_at' }

      it 'should convert option keys to symbols' do
        expect(Mongoid::History.trackable_settings[:ModelOne]).to eq(paranoia_field: 'erased_at')
      end
    end

    context 'when paranoia field has alias' do
      before(:each) do
        Mongoid::History.trackable_settings = nil
        model_two.history_settings paranoia_field: :neglected_at
      end

      let(:model_two) do
        Class.new do
          include Mongoid::Document
          include Mongoid::History::Trackable
          field :nglt, as: :neglected_at

          def self.name
            'ModelTwo'
          end
        end
      end

      it { expect(Mongoid::History.trackable_settings[:ModelTwo]).to eq(paranoia_field: 'nglt') }
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

    describe '#modified_attributes_for_update' do
      before(:all) do
        ModelOne = Class.new do
          include Mongoid::Document
          include Mongoid::History::Trackable
          store_in collection: :model_ones
          field :foo
          embeds_many :emb_ones, inverse_class_name: 'EmbOne'
        end

        EmbOne = Class.new do
          include Mongoid::Document
          include Mongoid::History::Trackable
          field :em_foo
          embedded_in :model_one
        end
      end

      before(:each) do
        model_one.save!
        ModelOne.instance_variable_set(:@history_trackable_options, nil)
        ModelOne.instance_variable_set(:@trackable_settings, nil)
        EmbOne.instance_variable_set(:@trackable_settings, nil)
      end

      let(:model_one) { ModelOne.new(foo: 'Foo') }
      let(:changes) { {} }
      subject { model_one.send(:modified_attributes_for_update) }

      describe 'embeds_many' do
        before(:each) { allow(model_one).to receive(:changes) { changes } }

        context 'when not paranoia' do
          before(:each) { ModelOne.track_history(on: :emb_ones) }
          let(:changes) { { 'emb_ones' => [[{ 'em_foo' => 'Foo' }], [{ 'em_foo' => 'Foo-new' }]] } }
          it { expect(subject['emb_ones'][0]).to eq [{ 'em_foo' => 'Foo' }] }
          it { expect(subject['emb_ones'][1]).to eq [{ 'em_foo' => 'Foo-new' }] }
        end

        context 'when default field for paranoia' do
          before(:each) { ModelOne.track_history(on: :emb_ones) }
          let(:changes) do
            { 'emb_ones' => [[{ 'em_foo' => 'Foo' }, { 'em_foo' => 'Foo-2', 'deleted_at' => Time.now }],
                             [{ 'em_foo' => 'Foo-new' }, { 'em_foo' => 'Foo-2-new', 'deleted_at' => Time.now }]] }
          end
          it { expect(subject['emb_ones'][0]).to eq [{ 'em_foo' => 'Foo' }] }
          it { expect(subject['emb_ones'][1]).to eq [{ 'em_foo' => 'Foo-new' }] }
        end

        context 'when custom field for paranoia' do
          before(:each) do
            ModelOne.track_history on: :emb_ones
            EmbOne.history_settings paranoia_field: :my_paranoia_field
          end
          let(:changes) do
            { 'emb_ones' => [[{ 'em_foo' => 'Foo', 'my_paranoia_field' => Time.now },
                              { 'em_foo' => 'Foo-2' }],
                             [{ 'em_foo' => 'Foo-new', 'my_paranoia_field' => Time.now },
                              { 'em_foo' => 'Foo-2-new' }]] }
          end
          it { expect(subject['emb_ones'][0]).to eq [{ 'em_foo' => 'Foo-2' }] }
          it { expect(subject['emb_ones'][1]).to eq [{ 'em_foo' => 'Foo-2-new' }] }
        end
      end

      describe 'fields' do
        context 'when custom method for changes' do
          before(:each) do
            ModelOne.clear_trackable_memoization
            ModelOne.track_history(on: :foo, changes_method: :my_changes_method)
            allow(ModelOne).to receive(:dynamic_enabled?) { false }
            allow(model_one).to receive(:my_changes_method) { changes }
          end
          let(:changes) { { 'foo' => ['Foo', 'Foo-new'], 'bar' => ['Bar', 'Bar-new'] } }
          it { is_expected.to eq('foo' => ['Foo', 'Foo-new']) }
        end
      end

      after(:all) do
        Object.send(:remove_const, :ModelOne)
        Object.send(:remove_const, :EmbOne)
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

  describe '#track_update' do
    before :all do
      MyModel.track_history(on: :foo, track_update: true)
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }
    let!(:m) { MyModel.create!(foo: 'bar') }

    it 'should create history' do
      expect { m.update_attributes!(foo: 'bar2') }.to change(Tracker, :count).by(1)
    end

    it 'should not create history when error raised' do
      expect(m).to receive(:update_attributes!).and_raise(StandardError)
      expect do
        expect { m.update_attributes!(foo: 'bar2') }.to raise_error(StandardError)
      end.to change(Tracker, :count).by(0)
    end
  end

  describe '#track_destroy' do
    before :all do
      MyModel.track_history(on: :foo, track_destroy: true)
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }
    let!(:m) { MyModel.create!(foo: 'bar') }

    it 'should create history' do
      expect { m.destroy }.to change(Tracker, :count).by(1)
    end

    it 'should not create history when error raised' do
      expect(m).to receive(:destroy).and_raise(StandardError)
      expect do
        expect { m.destroy }.to raise_error(StandardError)
      end.to change(Tracker, :count).by(0)
    end
  end

  describe '#track_create' do
    before :all do
      MyModel.track_history(on: :foo, track_create: true)
      @persisted_history_options = Mongoid::History.trackable_class_options
      MyModelWithNoModifier.track_history modifier_field: nil
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }

    it 'should create history' do
      expect { MyModel.create!(foo: 'bar') }.to change(Tracker, :count).by(1)
    end

    context 'no modifier_field' do
      it 'should create history' do
        expect { MyModelWithNoModifier.create!(foo: 'bar').to change(Tracker, :count).by(1) }
      end
    end

    it 'should not create history when error raised' do
      expect(MyModel).to receive(:create!).and_raise(StandardError)
      expect do
        expect { MyModel.create!(foo: 'bar') }.to raise_error(StandardError)
      end.to change(Tracker, :count).by(0)
    end
  end
end
