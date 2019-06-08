require 'spec_helper'

describe Mongoid::History::Tracker do
  describe 'Tracking of changes from embedded documents' do
    before :each do
      # Child model (will be embedded in Parent)
      class Child
        include Mongoid::Document
        include Mongoid::History::Trackable

        store_in collection: :child

        field :name
        embedded_in :parent, inverse_of: :child
      end

      # Parent model (embeds one Child)
      class Parent
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :name, type: String
        embeds_one :child

        store_in collection: :parent

        track_history(
          on: %i[fields embedded_relations],
          version_field: :version,
          track_create: true,
          track_update: true,
          track_destroy: false,
          modifier_field: nil
        )
      end
    end

    after :each do
      Object.send(:remove_const, :Parent)
      Object.send(:remove_const, :Child)
    end

    it 'tracks history for nested embedded documents in parent' do
      parent = Parent.new(name: 'bowser')
      parent.child = Child.new(name: 'todd')
      parent.save!
      expect(parent.history_tracks.length).to eq(1)
      change = parent.history_tracks.last
      aggregate_failures do
        expect(change.modified['name']).to eq('bowser')
        expect(change.modified['child']['name']).to eq('todd')
      end

      parent.update_attributes(name: 'brow')
      expect(parent.history_tracks.length).to eq(2)

      parent.child.name = 'mario'
      parent.save!
      expect(parent.history_tracks.length).to eq(3)

      aggregate_failures do
        track = parent.history_tracks.last
        expect(track.original['child']['name']).to eq('todd')
        expect(track.modified['child']['name']).to eq('mario')
      end
    end
  end
end
