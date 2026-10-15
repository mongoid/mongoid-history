require 'spec_helper'

describe 'History tracking callback boundaries' do
  before do
    class CallbackBoundaryDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      track_history on: [:title], modifier_field: nil
    end
  end

  after do
    Object.send(:remove_const, :CallbackBoundaryDocument)
  end

  let(:document) { CallbackBoundaryDocument.create!(title: 'original') }

  it 'does not invent history for an atomic set that bypasses callbacks' do
    document
    expect do
      if Mongoid::Compatibility::Version.mongoid3?
        document.set(:title, 'atomic')
      else
        document.set(title: 'atomic')
      end
    end.not_to change(Tracker, :count)
    expect(document.reload.title).to eq('atomic')
    expect(document.version).to eq(1)
    expect(document.history_tracks.last.modified['title']).to eq('original')
  end

  it 'tracks callback-based updates with the actual original and modified values' do
    document
    expect { document.update_attributes!(title: 'updated') }.to change(Tracker, :count).by(1)
    expect(document.reload.version).to eq(2)
    expect(document.history_tracks.last.original['title']).to eq('original')
    expect(document.history_tracks.last.modified['title']).to eq('updated')
  end

  it 'does not track criteria updates that bypass callbacks' do
    document
    expect do
      CallbackBoundaryDocument.where(id: document.id).update_all(title: 'criteria')
    end.not_to change(Tracker, :count)
    expect(document.reload.title).to eq('criteria')
    expect(document.version).to eq(1)
  end

  if Mongoid::Compatibility::Version.mongoid5_or_newer?
    it 'does not track driver bulk writes that bypass Mongoid' do
      document
      expect do
        CallbackBoundaryDocument.collection.bulk_write(
          [{ update_one: { filter: { _id: document.id }, update: { '$set' => { title: 'bulk' } } } }]
        )
      end.not_to change(Tracker, :count)
      expect(document.reload.title).to eq('bulk')
      expect(document.version).to eq(1)
    end
  end
end
