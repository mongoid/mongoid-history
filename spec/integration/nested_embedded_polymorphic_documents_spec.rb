require 'spec_helper'

describe Mongoid::History::Tracker do
  before :each do
    class ModelOne
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user
      embeds_one :one_embedded, as: :embedable

      track_history
    end

    class ModelTwo
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user
      embeds_one :one_embedded, as: :embedable

      track_history
    end

    class OneEmbedded
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embeds_many :embedded_twos, store_as: :ems
      embedded_in :embedable, polymorphic: true

      track_history scope: %i[model_one model_two]
    end

    class EmbeddedTwo
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embedded_in :one_embedded

      track_history scope: %i[model_one model_two]
    end

    class User
      include Mongoid::Document

      has_many :model_ones
      has_many :model_twos
    end
  end

  after :each do
    Object.send(:remove_const, :ModelOne)
    Object.send(:remove_const, :ModelTwo)
    Object.send(:remove_const, :OneEmbedded)
    Object.send(:remove_const, :EmbeddedTwo)
    Object.send(:remove_const, :User)
  end

  let (:user) { User.create! }

  it 'tracks history for nested embedded documents with polymorphic relations' do
    user = User.create!

    model_one = user.model_ones.build(name: 'model_one', modifier: user)
    model_one.save!
    model_one.build_one_embedded(name: 'model_one_one_embedded', modifier: user).save!
    expect(model_one.history_tracks.count).to eq(2)
    expect(model_one.one_embedded.history_tracks.count).to eq(1)

    model_one.reload
    model_one.one_embedded.update_attributes!(name: 'model_one_embedded_one!')
    expect(model_one.history_tracks.count).to eq(3)
    expect(model_one.one_embedded.history_tracks.count).to eq(2)
    expect(model_one.history_tracks.last.action).to eq('update')

    model_one.build_one_embedded(name: 'Lorem ipsum', modifier: user).save!
    expect(model_one.history_tracks.count).to eq(4)
    expect(model_one.one_embedded.history_tracks.count).to eq(1)
    expect(model_one.one_embedded.history_tracks.last.action).to eq('create')
    expect(model_one.one_embedded.history_tracks.last.association_chain.last['name']).to eq('one_embedded')

    embedded_one1 = model_one.one_embedded.embedded_twos.create!(name: 'model_one_one_embedded_1', modifier: user)
    expect(model_one.history_tracks.count).to eq(5)
    expect(model_one.one_embedded.history_tracks.count).to eq(2)
    expect(embedded_one1.history_tracks.count).to eq(1)

    model_two = user.model_twos.build(name: 'model_two', modifier: user)
    model_two.save!
    model_two.build_one_embedded(name: 'model_two_one_embedded', modifier: user).save!
    expect(model_two.history_tracks.count).to eq(2)
    expect(model_two.one_embedded.history_tracks.count).to eq(1)

    model_two.reload
    model_two.one_embedded.update_attributes!(name: 'model_two_one_embedded!')
    expect(model_two.history_tracks.count).to eq(3)
    expect(model_two.one_embedded.history_tracks.count).to eq(2)
    expect(model_two.history_tracks.last.action).to eq('update')

    model_two.build_one_embedded(name: 'Lorem ipsum', modifier: user).save!
    expect(model_two.history_tracks.count).to eq(4)
    expect(model_two.one_embedded.history_tracks.count).to eq(1)
    expect(model_two.one_embedded.history_tracks.last.action).to eq('create')
    expect(model_two.one_embedded.history_tracks.last.association_chain.last['name']).to eq('one_embedded')

    embedded_one2 = model_two.one_embedded.embedded_twos.create!(name: 'model_two_one_embedded_1', modifier: user)
    expect(model_two.history_tracks.count).to eq(5)
    expect(model_two.one_embedded.history_tracks.count).to eq(2)
    expect(embedded_one2.history_tracks.count).to eq(1)
  end
end
