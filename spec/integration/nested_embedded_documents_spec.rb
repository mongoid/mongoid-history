require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Modelone
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user, inverse_of: :modelones
      embeds_many :embones

      track_history on: :all, # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: false,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false    # track document destruction, default is false
    end

    class Embone
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embeds_many :embtwos, store_as: :ems
      embedded_in :modelone

      track_history on: :all, # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: false,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false, # track document destruction, default is false
                    scope: :model
    end

    class Embtwo
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embedded_in :embone

      track_history on: :all, # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: false,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false, # track document destruction, default is false
                    scope: :modelone
    end

    class User
      include Mongoid::Document
      has_many :modelones, dependent: :destroy, inverse_of: :user
    end
  end

  it 'should be able to track history for nested embedded documents' do
    user = User.new
    user.save!

    model = Modelone.new(name: 'm1name')
    model.user = user
    model.save!
    embedded1 = model.embones.create(name: 'e1name')
    embedded2 = embedded1.embtwos.create(name: 'e2name')

    embedded2.name = 'a new name'
    embedded2.save!

    model.history_tracks.first.undo! user
    expect(embedded1.reload.name).to eq('e1name')
    expect(embedded2.reload.name).to eq('e2name')
  end

  after :all do
    Object.send(:remove_const, :Modelone)
    Object.send(:remove_const, :Embone)
    Object.send(:remove_const, :Embtwo)
    Object.send(:remove_const, :User)
  end
end
