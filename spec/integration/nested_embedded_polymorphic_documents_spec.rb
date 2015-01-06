require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Modelone
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user
      embeds_one :embedded_one,  as: :embedable

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
      embeds_one :embedded_one,  as: :embedable

      track_history on: :all,
                    modifier_field: :modifier,
                    version_field: :version,
                    track_create: true,
                    track_update: true,
                    track_destroy: true
    end

    class EmbeddedOne
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
      embedded_in :embedded_one

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
    modelone.build_embedded_one(name: 'modelone_embedded_one').save!
    expect(modelone.history_tracks.count).to eq(2)
    expect(modelone.embedded_one.history_tracks.count).to eq(1)

    modelone.reload
    modelone.embedded_one.update_attribute(:name, 'modelone_embedded_one!')
    expect(modelone.history_tracks.count).to eq(3)
    expect(modelone.embedded_one.history_tracks.count).to eq(2)
    expect(modelone.history_tracks.last.action).to eq('update')

    modelone.build_embedded_one(name: 'Lorem ipsum').save!
    expect(modelone.history_tracks.count).to eq(4)
    expect(modelone.embedded_one.history_tracks.count).to eq(1)
    expect(modelone.history_tracks.last.action).to eq('create')
    expect(modelone.history_tracks.last.association_chain.last['name']).to eq('embedded_one')

    embedded_one1 = modelone.embedded_one.embedded_twos.create(name: 'modelone_embedded_one_1')
    expect(modelone.history_tracks.count).to eq(5)
    expect(modelone.embedded_one.history_tracks.count).to eq(2)
    expect(embedded_one1.history_tracks.count).to eq(1)

    modeltwo = user.modeltwos.build(name: 'modeltwo')
    modeltwo.save!
    modeltwo.build_embedded_one(name: 'modeltwo_embedded_one').save!
    expect(modeltwo.history_tracks.count).to eq(2)
    expect(modeltwo.embedded_one.history_tracks.count).to eq(1)

    modeltwo.reload
    modeltwo.embedded_one.update_attribute(:name, 'modeltwo_embedded_one!')
    expect(modeltwo.history_tracks.count).to eq(3)
    expect(modeltwo.embedded_one.history_tracks.count).to eq(2)
    expect(modeltwo.history_tracks.last.action).to eq('update')

    modeltwo.build_embedded_one(name: 'Lorem ipsum').save!
    expect(modeltwo.history_tracks.count).to eq(4)
    expect(modeltwo.embedded_one.history_tracks.count).to eq(1)
    expect(modeltwo.history_tracks.last.action).to eq('create')
    expect(modeltwo.history_tracks.last.association_chain.last['name']).to eq('embedded_one')

    embedded_one2 = modeltwo.embedded_one.embedded_twos.create(name: 'modeltwo_embedded_one_1')
    expect(modeltwo.history_tracks.count).to eq(5)
    expect(modeltwo.embedded_one.history_tracks.count).to eq(2)
    expect(embedded_one2.history_tracks.count).to eq(1)
  end
end
