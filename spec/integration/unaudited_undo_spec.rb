require 'spec_helper'

describe 'Undo without recording another change' do
  before do
    class UnauditedUndoDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      track_history on: [:title], modifier_field: nil, version_field: :revision
    end
  end

  after do
    UnauditedUndoDocument.delete_all
    Tracker.delete_all
    Object.send(:remove_const, :UnauditedUndoDocument)
  end

  let(:document) do
    record = UnauditedUndoDocument.create!(title: 'First')
    record.update_attributes!(title: 'Second')
    record.update_attributes!(title: 'Third')
    record
  end

  it 'allows repeated explicit undo selections without creating history or reusing version numbers' do
    expect(document.undo!(nil, from: 3, to: 3, history: false)).to be_truthy
    expect(document.reload.title).to eq('Second')
    document.undo!(nil, from: 2, to: 2, history: false)
    expect(document.reload.title).to eq('First')
    expect(document.history_tracks.count).to eq(3)
    expect(document.revision).to eq(3)
    document.update_attributes!(title: 'Fourth')
    expect(document.revision).to eq(4)
    expect(document.history_tracks.count).to eq(4)
  end

  it 'supports one explicit batch while leaving audited undo as the default' do
    document.undo!(nil, last: 2, history: false)
    expect(document.reload.title).to eq('First')
    expect(document.history_tracks.count).to eq(3)
    document.undo!(nil, 2)
    expect(document.history_tracks.count).to eq(3)
    document.update_attributes!(title: 'Another')
    document.undo!
    expect(document.history_tracks.count).to eq(5)
  end

  it 'rejects ambiguous requests and restores the tracking flag on save failure' do
    expect { document.undo!(nil, history: false) }.to raise_error(ArgumentError)
    allow(document).to receive(:save!).and_raise('save failed')
    expect { document.undo!(nil, last: 1, history: false) }.to raise_error('save failed')
    expect(Mongoid::History.enabled?).to be true
  end

  it 'restores previously disabled tracking after unaudited undo' do
    record = document
    Mongoid::History.disable do
      record.undo!(nil, last: 1, history: false)
      expect(Mongoid::History.enabled?).to be false
    end
    expect(Mongoid::History.enabled?).to be true
    expect(record.reload.title).to eq('Second')
    expect(record.history_tracks.count).to eq(3)
  end
end
