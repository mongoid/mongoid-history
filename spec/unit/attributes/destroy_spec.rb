require 'spec_helper'

describe Mongoid::History::Attributes::Destroy do
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

    describe '#fields' do
      before(:each) do
        model_one.instance_variable_set(:@history_trackable_options, nil)
        model_one.track_history on: :foo, modifier_field_optional: true
        obj_one.save!
      end
      let(:obj_one) { model_one.new(foo: 'Foo', bar: 'Bar') }
      it { is_expected.to eq('_id' => [obj_one._id, nil], 'foo' => ['Foo', nil], 'version' => [1, nil]) }
    end

    describe '#insert_embeds_one_changes' do
      before(:all) do
        # Need class name constant. So, defining class like this
        class ModelTwo
          include Mongoid::Document
          include Mongoid::History::Trackable
          store_in collection: :model_twos
          embeds_one :emb_two
          track_history on: :fields, modifier_field_optional: true
        end

        class EmbTwo
          include Mongoid::Document
          field :em_foo
          field :em_bar
          embedded_in :model_two
        end
      end

      before(:each) { ModelTwo.clear_trackable_memoization }
      let(:obj_two) { ModelTwo.new(emb_two: emb_obj_two) }
      let(:emb_obj_two) { EmbTwo.new(em_foo: 'Em-Foo', em_bar: 'Em-Bar') }
      let(:base) { described_class.new(obj_two) }

      context 'when relation tracked' do
        before(:each) do
          ModelTwo.track_history on: :emb_two, modifier_field_optional: true
          obj_two.save!
        end
        it { expect(subject['emb_two']).to eq [{ '_id' => emb_obj_two._id, 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }, nil] }
      end

      context 'when relation not tracked' do
        before(:each) do
          ModelTwo.track_history on: :fields, modifier_field_optional: true
          allow(ModelTwo).to receive(:dynamic_enabled?) { false }
          obj_two.save!
        end
        it { expect(subject['emb_two']).to be_nil }
      end

      context 'when relation with alias' do
        before(:all) do
          # Need class name constant. So, defining class like this
          class ModelThree
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_threes
            embeds_one :emb_three, store_as: :emtr
          end

          class EmbThree
            include Mongoid::Document
            field :em_foo
            embedded_in :model_three
          end
        end

        before(:each) do
          ModelThree.instance_variable_set(:@history_trackable_options, nil)
          ModelThree.track_history on: :emb_three, modifier_field_optional: true
          obj_three.save!
        end

        let(:obj_three) { ModelThree.new(emb_three: emb_obj_three) }
        let(:emb_obj_three) { EmbThree.new(em_foo: 'Em-Foo') }
        let(:base) { described_class.new(obj_three) }
        it { expect(subject['emb_three']).to eq [{ '_id' => emb_obj_three._id, 'em_foo' => 'Em-Foo' }, nil] }

        after(:all) do
          Object.send(:remove_const, :ModelThree)
          Object.send(:remove_const, :EmbThree)
        end
      end

      context 'relation with permitted attributes' do
        before(:each) do
          ModelTwo.track_history on: [{ emb_two: :em_foo }], modifier_field_optional: true
          obj_two.save!
        end
        it { expect(subject['emb_two']).to eq [{ '_id' => emb_obj_two._id, 'em_foo' => 'Em-Foo' }, nil] }
      end

      context 'when relation object not built' do
        before(:each) do
          ModelTwo.track_history on: :emb_two, modifier_field_optional: true
          obj_two.save!
        end
        let(:obj_two) { ModelTwo.new }
        it { expect(subject['emb_two']).to be_nil }
      end

      after(:all) do
        Object.send(:remove_const, :ModelTwo)
        Object.send(:remove_const, :EmbTwo)
      end
    end

    describe '#insert_embeds_many_changes' do
      context 'Case 1:' do
        before(:all) do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            embeds_many :em_twos
            track_history on: :fields
          end

          class EmTwo
            include Mongoid::Document
            field :em_foo
            field :em_bar
            embedded_in :model_two
          end
        end

        let(:obj_two) { ModelTwo.new(em_twos: [em_obj_two]) }
        let(:em_obj_two) { EmTwo.new(em_foo: 'Em-Foo', em_bar: 'Em-Bar') }
        let(:base) { described_class.new(obj_two) }

        context 'when relation tracked' do
          before(:each) do
            ModelTwo.clear_trackable_memoization
            ModelTwo.track_history on: :em_twos
          end
          it { expect(subject['em_twos']).to eq [[{ '_id' => em_obj_two._id, 'em_foo' => 'Em-Foo', 'em_bar' => 'Em-Bar' }], nil] }
        end

        context 'when relation not tracked' do
          before(:each) do
            ModelTwo.clear_trackable_memoization
            ModelTwo.track_history on: :fields
          end
          it { expect(subject['em_twos']).to be_nil }
        end

        context 'when relation with permitted attributes for tracking' do
          before(:each) do
            ModelTwo.clear_trackable_memoization
            ModelTwo.track_history on: { em_twos: :em_foo }
          end
          it { expect(subject['em_twos']).to eq [[{ '_id' => em_obj_two._id, 'em_foo' => 'Em-Foo' }], nil] }
        end

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmTwo)
        end
      end

      context 'when relation with alias' do
        before(:all) do
          class ModelTwo
            include Mongoid::Document
            include Mongoid::History::Trackable
            embeds_many :em_twos, store_as: :emws
            track_history on: :fields
          end

          class EmTwo
            include Mongoid::Document
            field :em_foo
            embedded_in :model_two
          end
        end

        before(:each) do
          ModelTwo.clear_trackable_memoization
          ModelTwo.track_history on: :em_twos
        end

        let(:obj_two) { ModelTwo.new(em_twos: [em_obj_two]) }
        let(:em_obj_two) { EmTwo.new(em_foo: 'Em-Foo') }
        let(:base) { described_class.new(obj_two) }

        it { expect(subject['em_twos']).to eq [[{ '_id' => em_obj_two._id, 'em_foo' => 'Em-Foo' }], nil] }

        after(:all) do
          Object.send(:remove_const, :ModelTwo)
          Object.send(:remove_const, :EmTwo)
        end
      end
    end
  end
end
