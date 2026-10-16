require 'spec_helper'

describe 'Custom changes method values' do
  before do
    class CustomChangesDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :key
      field :enabled, type: Boolean
      field :tags, type: Array
      track_history on: %i[key enabled tags], changes_method: :history_changes, modifier_field: nil

      def history_changes
        return changes unless changes.key?('key')

        changes.merge('key' => [changes.fetch('key').first, "Save history-#{key}"])
      end
    end
  end

  after do
    CustomChangesDocument.delete_all
    Tracker.delete_all
    Object.send(:remove_const, :CustomChangesDocument)
  end

  it 'records explicit change pairs on create and update without changing the document' do
    document = CustomChangesDocument.create!(key: 'created')
    track = document.history_tracks.last.reload
    expect(track.original).to eq({})
    expect(track.modified).to eq('key' => 'Save history-created')

    document.update_attributes!(key: 'updated')
    track = document.history_tracks.last.reload
    expect(track.original).to eq('key' => 'created')
    expect(track.modified).to eq('key' => 'Save history-updated')
    expect(document.reload.key).to eq('updated')
  end

  it 'retains explicit before/after pairs with symbol keys' do
    document = CustomChangesDocument.create!(key: 'created')
    allow(document).to receive(:history_changes).and_return(key: %w[before after])
    document.update_attributes!(key: 'updated')
    track = document.history_tracks.last.reload
    expect(track.original).to eq('key' => 'before')
    expect(track.modified).to eq('key' => 'after')
  end

  it 'preserves false and nil within change pairs' do
    document = CustomChangesDocument.create!(key: 'created', enabled: true)
    allow(document).to receive(:history_changes).and_return('enabled' => [true, false], 'key' => ['created', nil])
    document.update_attributes!(enabled: false, key: nil)
    track = document.history_tracks.last.reload
    expect(track.original).to eq('key' => 'created', 'enabled' => true)
    expect(track.modified).to eq('enabled' => false)
  end

  it 'records array-valued fields within change pairs' do
    document = CustomChangesDocument.create!(tags: ['old'])
    document.update_attributes!(tags: ['new'])
    track = document.history_tracks.last.reload
    expect(track.original).to eq('tags' => ['old'])
    expect(track.modified).to eq('tags' => ['new'])
  end

  it 'accepts an empty custom changes hash' do
    document = CustomChangesDocument.create!(key: 'created')
    allow(document).to receive(:history_changes).and_return({})
    document.update_attributes!(key: 'updated')
    expect(document.reload.key).to eq('updated')
    expect(document.history_tracks.count).to eq(1)
  end

  it 'continues to snapshot actual attributes when a document is destroyed' do
    document = CustomChangesDocument.create!(key: 'created')
    document.destroy
    track = Tracker.where(action: 'destroy').last.reload
    expect(track.original['key']).to eq('created')
    expect(track.modified).to eq({})
  end
end
