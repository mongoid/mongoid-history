require 'spec_helper'

describe Mongoid::History::Tracker, focus: true do
  before :all do
    # Child model (will be embedded in Parent)
    class Child
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embedded_in :parent, inverse_of: :child
    end

    # Parent model (embeds one Child)
    class Parent
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      embeds_one :child

      track_history on: %i[(fields embedded_relations)],
                    version_field: :version,
                    track_create: true,
                    track_update: true,
                    track_destroy: false
    end
  end

  it 'should be able to track history for nested embedded documents in parent' do
    p = Parent.new(name: 'bowser')
    p.child = Child.new(name: 'todd')
    p.save!

    expect(p.history_tracks.length).to eq(1)
    change = p.history_tracks.last
    expect(change.modified['name']).to eq('bowser')
    expect(change.modified['child']['name']).to eq('todd')

    p.child.name = 'mario'
    p.save!

    expect(p.history_tracks.length).to eq(2)
    expect(p.history_tracks.last.modified['child']['name']).to eq('mario')
  end

  after :all do
    Object.send(:remove_const, :Parent)
    Object.send(:remove_const, :Child)
  end
end
