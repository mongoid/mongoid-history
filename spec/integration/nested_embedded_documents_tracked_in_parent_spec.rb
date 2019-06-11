require 'spec_helper'

describe Mongoid::History::Tracker do
  describe 'Tracking of changes from embedded documents' do
    before :each do
      # Child model (will be embedded in Parent)
      class Child
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :name
        embedded_in :parent, inverse_of: :child
        embeds_one :child, inverse_of: :parent, class_name: 'NestedChild'
      end

      # NestedChild model (will be embedded in Child)
      class NestedChild
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :name
        embedded_in :parent, inverse_of: :child, class_name: 'Child'
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
      Object.send(:remove_const, :NestedChild)
    end

    context 'with a parent-child hierarchy' do
      let(:parent) do
        Parent.create!(name: 'bowser', child: Child.new(name: 'todd'))
      end

      it 'tracks history for the nested embedded documents in the parent' do
        expect(parent.history_tracks.length).to eq(1)

        aggregate_failures do
          track = parent.history_tracks.last
          expect(track.modified['name']).to eq('bowser')
          expect(track.modified.dig('child', 'name')).to eq('todd')
        end

        parent.update_attributes(name: 'brow')
        expect(parent.history_tracks.length).to eq(2)

        parent.child.name = 'mario'
        parent.save!
        expect(parent.history_tracks.length).to eq(3)

        aggregate_failures do
          track = parent.history_tracks.last
          expect(track.original.dig('child', 'name')).to eq('todd')
          expect(track.modified.dig('child', 'name')).to eq('mario')
        end
      end
    end

    context 'with a deeply nested hierarchy' do
      let(:parent) do
        Parent.create!(
          name: 'bowser',
          child: Child.new(
            name: 'todd',
            child: NestedChild.new(name: 'peach')
          )
        )
      end

      it 'tracks history for deeply nested embedded documents in parent' do
        pending('Figure out a way to track deeply nested relation changes')

        expect(parent.history_tracks.length).to eq(1)

        aggregate_failures do
          track = parent.history_tracks.last
          expect(track.modified['name']).to eq('bowser')
          expect(track.modified.dig('child', 'name')).to eq('todd')
          expect(track.modified.dig('child', 'child', 'name')).to eq('peach')
        end

        parent.name = 'brow'
        parent.child.name = 'mario'
        parent.child.child.name = 'luigi'
        parent.save!
        expect(parent.history_tracks.length).to eq(2)

        aggregate_failures do
          track = parent.history_tracks.last
          expect(track.original['name']).to eq('bowser')
          expect(track.modified['name']).to eq('brow')

          expect(track.original['child']['name']).to eq('todd')
          expect(track.modified['child']['name']).to eq('mario')

          expect(track.original['child']['child']['name']).to eq('peach')
          expect(track.modified['child']['child']['name']).to eq('luigi')
        end
      end
    end
  end
end
