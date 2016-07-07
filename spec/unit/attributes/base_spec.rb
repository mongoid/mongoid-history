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
end
