require 'spec_helper'

describe Mongoid::History::Attributes::Base do
  let(:model_one) do
    Class.new do
      include Mongoid::Document
      include Mongoid::History::Trackable
      field :foo
      field :b, as: :bar
      def self.name
        'ModelOne'
      end
    end
  end

  before :all do
    class ModelTwo
      include Mongoid::Document
      field :foo
      field :goo
    end
  end

  after :all do
    Object.send(:remove_const, :ModelTwo)
  end

  let(:obj_one) { model_one.new }
  let(:base) { described_class.new(obj_one) }
  subject { base }

  it { is_expected.to respond_to(:trackable) }

  describe '#initialize' do
    it { expect(base.instance_variable_get(:@trackable)).to eq obj_one }
  end

  describe '#trackable_class' do
    subject { base.send(:trackable_class) }
    it { is_expected.to eq model_one }
  end

  describe '#aliased_fields' do
    subject { base.send(:aliased_fields) }
    it { is_expected.to eq('id' => '_id', 'bar' => 'b') }
  end

  describe '#changes_method' do
    before(:each) do
      model_one.instance_variable_set(:@history_trackable_options, nil)
      model_one.track_history changes_method: :my_changes
    end
    subject { base.send(:changes_method) }
    it { is_expected.to eq :my_changes }
  end

  describe '#changes' do
    before(:each) do
      model_one.instance_variable_set(:@history_trackable_options, nil)
      model_one.track_history
      allow(obj_one).to receive(:changes) { { 'foo' => ['Foo', 'Foo-new'] } }
    end
    subject { base.send(:changes) }
    it { is_expected.to eq('foo' => ['Foo', 'Foo-new']) }
  end

  describe '#format_field' do
    before(:each) do
      model_one.instance_variable_set(:@history_trackable_options, nil)
    end

    subject { base.send(:format_field, :bar, 'foo') }

    context 'when formatted via string' do
      before do
        model_one.track_history format: { bar: '*%s*' }
      end

      it { is_expected.to eq '*foo*' }
    end

    context 'when formatted via proc' do
      before do
        model_one.track_history format: { bar: ->(v) { v * 2 } }
      end

      it { is_expected.to eq 'foofoo' }
    end

    context 'when not formatted' do
      before do
        model_one.track_history
      end

      it { is_expected.to eq 'foo' }
    end
  end

  shared_examples 'formats embedded relation' do |relation_type|
    let(:model_two) { ModelTwo.new(foo: :bar, goo: :baz) }

    before :each do
      model_one.instance_variable_set(:@history_trackable_options, nil)
      model_one.send(relation_type, :model_two)
    end

    subject { base.send("format_#{relation_type}_relation", :model_two, model_two.attributes) }

    context 'with permitted attributes' do
      before do
        model_one.track_history on: { model_two: %i(foo) }
      end

      it 'should select only permitted attributes' do
        is_expected.to include('foo' => :bar)
        is_expected.to_not include('goo')
      end
    end

    context 'with attributes formatted via string' do
      before do
        model_one.track_history on: { model_two: %i(foo) }, format: { model_two: { foo: '&%s&' } }
      end

      it 'should select obfuscate permitted attributes' do
        is_expected.to include('foo' => '&bar&')
        is_expected.to_not include('goo')
      end
    end

    context 'with attributes formatted via proc' do
      before do
        model_one.track_history on: { model_two: %i(foo) }, format: { model_two: { foo: ->(v) { v.to_s * 2 } } }
      end

      it 'should select obfuscate permitted attributes' do
        is_expected.to include('foo' => 'barbar')
        is_expected.to_not include('goo')
      end
    end
  end

  describe '#format_embeds_one_relation' do
    include_examples 'formats embedded relation', :embeds_one
  end

  describe '#format_embeds_many_relation' do
    include_examples 'formats embedded relation', :embeds_many
  end
end
