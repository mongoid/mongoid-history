require 'spec_helper'

describe Mongoid::History::Options do
  before :all do
    ModelOne = Class.new do
      include Mongoid::Document
      include Mongoid::History::Trackable
      store_in collection: :model_ones
      field :foo
      attr_accessor :bar
      track_history track_create: true,
                    track_update: true,
                    track_destroy: true,
                    if: :bar
    end

    ModelTwo = Class.new do
      include Mongoid::Document
      include Mongoid::History::Trackable
      store_in collection: :model_twos
      field :foo
      attr_accessor :bar
      track_history track_create: true,
                    track_update: true,
                    track_destroy: true,
                    unless: ->(obj){obj.bar}
    end

    ModelThree = Class.new do
      include Mongoid::Document
      include Mongoid::History::Trackable
      store_in collection: :model_threes
      field :foo
      attr_accessor :bar, :baz
      track_history track_create: true,
                    track_update: true,
                    track_destroy: true,
                    if: ->(obj){obj.bar}, unless: :baz
    end
  end

  describe ':if' do
    # TODO: ModelOne
  end

  describe ':unless' do
    # TODO: ModelTwo
  end

  describe ':if and :unless' do
    # TODO: ModelThree
  end

  after :all do
    Object.send(:remove_const, :ModelOne)
    Object.send(:remove_const, :ModelTwo)
    Object.send(:remove_const, :ModelThree)
  end
end
