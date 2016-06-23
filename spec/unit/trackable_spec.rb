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
    before :all do
      MyModel.track_history
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }
    let(:expected_option) do
      { on: ['fields'],
        except: %w(created_at updated_at),
        modifier_field: :modifier,
        version_field: :version,
        changes_method: :changes,
        scope: :my_model,
        track_create: false,
        track_update: true,
        track_destroy: false,
        tracked_fields: %w(foo),
        tracked_relations: [],
        tracked_dynamic: [] }
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

  describe 'MyInstanceMethods' do
    before :all do
      MyTrackableModel = Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        field :foo
        field :b, as: :bar
        embeds_one :my_embed_one_model, inverse_class_name: 'MyEmbedOneModel'
        embeds_many :my_embed_many_models, inverse_class_name: 'MyEmbedManyModel'
      end

      MyEmbedOneModel = Class.new do
        include Mongoid::Document
        field :baz
        embedded_in :my_trackable_model
      end

      MyEmbedManyModel = Class.new do
        include Mongoid::Document
        field :bla
        embedded_in :my_trackable_model
      end

      MyTrackableModel.track_history(on: [:foo, :my_embed_one_model, :my_embed_many_models])
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }

    let(:my_embed_one_model) { MyEmbedOneModel.new(baz: 'Baz') }
    let(:my_embed_many_models) { [MyEmbedManyModel.new(bla: 'Bla')] }
    let(:my_trackable_model) do
      MyTrackableModel.new(foo: 'Foo',
                           bar: 'Bar',
                           my_embed_one_model: my_embed_one_model,
                           my_embed_many_models: my_embed_many_models)
    end

    describe '#modified_attributes_for_create' do
      subject { my_trackable_model.send(:modified_attributes_for_create) }

      it 'should include tracked fields' do
        expect(subject['foo']).to eq [nil, 'Foo']
        expect(subject['bar']).to be_nil
      end

      it 'should include tracked embeds_one objects attributes' do
        expect(subject['my_embed_one_model'][0]).to be_nil
        expect(subject['my_embed_one_model'][1]['_id']).to be_a BSON::ObjectId
        expect(subject['my_embed_one_model'][1]['baz']).to eq 'Baz'
      end

      it 'should include tracked embeds_many objects attributes' do
        expect(subject['my_embed_many_models'][0]).to be_nil
        expect(subject['my_embed_many_models'][1].size).to eq 1
        expect(subject['my_embed_many_models'][1][0]['_id']).to be_a BSON::ObjectId
        expect(subject['my_embed_many_models'][1][0]['bla']).to eq 'Bla'
      end

      context 'when embeds_one object blank' do
        let(:my_embed_one_model) { nil }

        it 'should not include embeds_one model key' do
          expect(subject.keys).to_not include 'my_embed_one_model'
        end
      end
    end

    describe '#modified_attributes_for_destroy' do
      subject { my_trackable_model.send(:modified_attributes_for_destroy) }

      it 'should track reserved fields' do
        expect(subject['_id'][0]).to be_a BSON::ObjectId
        expect(subject['_id'][1]).to be_nil
      end

      it 'should include tracked fields' do
        expect(subject['foo']).to eq ['Foo', nil]
        expect(subject['bar']).to be_nil
      end

      it 'should include tracked embeds_one objects attributes' do
        expect(subject['my_embed_one_model'][0]['_id']).to be_a BSON::ObjectId
        expect(subject['my_embed_one_model'][0]['baz']).to eq 'Baz'
        expect(subject['my_embed_one_model'][1]).to be_nil
      end

      it 'should include tracked embeds_many objects attributes' do
        expect(subject['my_embed_many_models'][0].size).to eq 1
        expect(subject['my_embed_many_models'][0][0]['_id']).to be_a BSON::ObjectId
        expect(subject['my_embed_many_models'][0][0]['bla']).to eq 'Bla'
        expect(subject['my_embed_many_models'][1]).to be_nil
      end

      context 'when embeds_one object blank' do
        let(:my_embed_one_model) { nil }

        it 'should not include embeds_one model key' do
          expect(subject.keys).to_not include 'my_embed_one_model'
        end
      end
    end

    after :all do
      Object.send(:remove_const, :MyTrackableModel)
      Object.send(:remove_const, :MyEmbedOneModel)
      Object.send(:remove_const, :MyEmbedManyModel)
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

    describe '#tracked_embedded_one?' do
      it { expect(MyTrackableModel.tracked_embedded_one?(:my_embed_one_model)).to be true }
      it { expect(MyTrackableModel.tracked_embedded_one?(:my_untracked_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embedded_one?(:my_embed_many_models)).to be false }
    end

    describe '#tracked_embedded_one' do
      it { expect(MyTrackableModel.tracked_embedded_one).to include 'my_embed_one_model' }
      it { expect(MyTrackableModel.tracked_embedded_one).to_not include 'my_untracked_embed_one_model' }
    end

    describe '#tracked_embedded_many?' do
      it { expect(MyTrackableModel.tracked_embedded_many?(:my_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embedded_many?(:my_untracked_embed_one_model)).to be false }
      it { expect(MyTrackableModel.tracked_embedded_many?(:my_embed_many_models)).to be true }
    end

    describe '#tracked_embedded_many' do
      it { expect(MyTrackableModel.tracked_embedded_many).to eq ['my_embed_many_models'] }
    end

    after :all do
      Object.send(:remove_const, :MyTrackableModel)
      Object.send(:remove_const, :MyEmbedOneModel)
      Object.send(:remove_const, :MyUntrackedEmbedOneModel)
      Object.send(:remove_const, :MyEmbedManyModel)
    end
  end
end
