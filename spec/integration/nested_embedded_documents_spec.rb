require 'spec_helper'

describe Mongoid::History::Tracker do
  before :each do
    class ModelOne
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user, inverse_of: :model_ones
      embeds_many :emb_ones

      track_history
    end

    class EmbOne
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embeds_many :emb_twos, store_as: :ems
      embedded_in :model_one

      track_history
    end

    class EmbTwo
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embedded_in :emb_one

      track_history scope: :model_one
    end

    class User
      include Mongoid::Document

      has_many :model_ones, dependent: :destroy, inverse_of: :user
    end
  end

  after :each do
    Object.send(:remove_const, :ModelOne)
    Object.send(:remove_const, :EmbOne)
    Object.send(:remove_const, :EmbTwo)
    Object.send(:remove_const, :User)
  end

  let(:user) { User.create! }

  it 'should be able to track history for nested embedded documents' do
    model = ModelOne.create!(name: 'm1name', user: user, modifier: user)
    embedded1 = model.emb_ones.create!(name: 'e1name', modifier: user)
    embedded2 = embedded1.emb_twos.create!(name: 'e2name', modifier: user)

    embedded2.update_attributes!(name: 'a new name')

    model.history_tracks[-1].undo! user
    expect(embedded1.reload.name).to eq('e1name')
    expect(embedded2.reload.name).to eq('e2name')
  end
end
