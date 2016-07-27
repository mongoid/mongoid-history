require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Modelone
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user
      embeds_one :one_embedded, as: :embedable

      track_history on: :all,
                    modifier_field: :modifier,
                    version_field: :version,
                    track_create: true,
                    track_update: true,
                    track_destroy: true
    end

    class Modeltwo
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user
      embeds_one :one_embedded, as: :embedable

      track_history on: :all,
                    modifier_field: :modifier,
                    version_field: :version,
                    track_create: true,
                    track_update: true,
                    track_destroy: true
    end

    class OneEmbedded
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embeds_many :embedded_twos, store_as: :ems
      embedded_in :embedable, polymorphic: true

      track_history on: :all,
                    modifier_field: :modifier,
                    version_field: :version,
                    track_create: true,
                    track_update: true,
                    track_destroy: true,
                    scope: [:modelone, :modeltwo]
    end

    class EmbeddedTwo
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embedded_in :one_embedded

      track_history on: :all,
                    modifier_field: :modifier,
                    version_field: :version,
                    track_create: true,
                    track_update: true,
                    track_destroy: true,
                    scope: [:modelone, :modeltwo]
    end

    class User
      include Mongoid::Document
      has_many :modelones
      has_many :modeltwos
    end
  end

  it 'tracks history for nested embedded documents with polymorphic relations' do
    user = User.new
    user.save!

    modelone = user.modelones.build(name: 'modelone')
    modelone.save!
    modelone.build_one_embedded(name: 'modelone_one_embedded').save!
    expect(modelone.history_tracks.count).to eq(2)
    expect(modelone.one_embedded.history_tracks.count).to eq(1)

    modelone.reload
    modelone.one_embedded.update_attribute(:name, 'modelone_embedded_one!')
    expect(modelone.history_tracks.count).to eq(3)
    expect(modelone.one_embedded.history_tracks.count).to eq(2)
    expect(modelone.history_tracks.last.action).to eq('update')

    modelone.build_one_embedded(name: 'Lorem ipsum').save!
    expect(modelone.history_tracks.count).to eq(4)
    expect(modelone.one_embedded.history_tracks.count).to eq(1)
    expect(modelone.one_embedded.history_tracks.last.action).to eq('create')
    expect(modelone.one_embedded.history_tracks.last.association_chain.last['name']).to eq('one_embedded')

    embedded_one1 = modelone.one_embedded.embedded_twos.create(name: 'modelone_one_embedded_1')
    expect(modelone.history_tracks.count).to eq(5)
    expect(modelone.one_embedded.history_tracks.count).to eq(2)
    expect(embedded_one1.history_tracks.count).to eq(1)

    modeltwo = user.modeltwos.build(name: 'modeltwo')
    modeltwo.save!
    modeltwo.build_one_embedded(name: 'modeltwo_one_embedded').save!
    expect(modeltwo.history_tracks.count).to eq(2)
    expect(modeltwo.one_embedded.history_tracks.count).to eq(1)

    modeltwo.reload
    modeltwo.one_embedded.update_attribute(:name, 'modeltwo_one_embedded!')
    expect(modeltwo.history_tracks.count).to eq(3)
    expect(modeltwo.one_embedded.history_tracks.count).to eq(2)
    expect(modeltwo.history_tracks.last.action).to eq('update')

    modeltwo.build_one_embedded(name: 'Lorem ipsum').save!
    expect(modeltwo.history_tracks.count).to eq(4)
    expect(modeltwo.one_embedded.history_tracks.count).to eq(1)
    expect(modeltwo.one_embedded.history_tracks.last.action).to eq('create')
    expect(modeltwo.one_embedded.history_tracks.last.association_chain.last['name']).to eq('one_embedded')

    embedded_one2 = modeltwo.one_embedded.embedded_twos.create(name: 'modeltwo_one_embedded_1')
    expect(modeltwo.history_tracks.count).to eq(5)
    expect(modeltwo.one_embedded.history_tracks.count).to eq(2)
    expect(embedded_one2.history_tracks.count).to eq(1)
  end
end
