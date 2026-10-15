require 'spec_helper'

describe 'Count-based history retention' do
  before do
    class RetainedDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      validates :title, presence: true
      embeds_many :retained_children
      track_history on: [:title], modifier_field: nil
    end

    class RetainedChild
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      embedded_in :retained_document
      track_history on: [:title], scope: :retained_document, modifier_field: nil
    end

    class RetainedOther
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      track_history on: [:title], modifier_field: nil
    end

    class RetentionTracker
      include Mongoid::History::Tracker
    end

    class CustomRetainedDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      track_history on: [:title], modifier_field: nil, tracker_class_name: :retention_tracker
    end
  end

  after do
    %i[RetainedDocument RetainedChild RetainedOther RetentionTracker CustomRetainedDocument].each do |name|
      Object.send(:remove_const, name)
    end
  end

  let(:document) { RetainedDocument.create!(title: 'first') }

  it 'retains the latest versions without renumbering them or resetting the document version' do
    document.update_attributes!(title: 'second')
    document.update_attributes!(title: 'third')
    expect(document.prune_history!(keep: 2)).to eq(1)
    expect(document.history_tracks.map(&:version)).to eq([2, 3])
    expect(document.reload.version).to eq(3)
    document.update_attributes!(title: 'fourth')
    expect(document.history_tracks.map(&:version)).to eq([2, 3, 4])
    expect(document.prune_history!(keep: 2)).to eq(1)
    expect(document.prune_history!(keep: 2)).to eq(0)
  end

  it 'does not remove another document, another scope, or embedded history' do
    other = RetainedDocument.create!(title: 'other')
    different_scope = RetainedOther.create!(id: document.id, title: 'other scope')
    child = document.retained_children.create!(title: 'child')
    child.update_attributes!(title: 'child edit')
    document.update_attributes!(title: 'second')

    expect(document.prune_history!(keep: 1)).to eq(1)
    expect(other.history_tracks.count).to eq(1)
    expect(different_scope.history_tracks.count).to eq(1)
    expect(child.history_tracks.count).to eq(2)
    expect(child.prune_history!(keep: 1)).to eq(1)
    expect(document.history_tracks.count).to eq(2)
  end

  it 'uses the configured tracker and leaves the default tracker unchanged' do
    document
    custom = CustomRetainedDocument.create!(title: 'first')
    custom.update_attributes!(title: 'second')
    expect { custom.prune_history!(keep: 1) }.not_to change(Tracker, :count)
    expect(custom.history_tracks.map(&:version)).to eq([2])
  end

  it 'uses id as a deterministic tie breaker for duplicate versions' do
    first = document.history_tracks.first
    duplicate = Tracker.create!(first.attributes.except('_id', 'created_at', 'updated_at'))
    retained_id = [first.id, duplicate.id].max
    expect(document.prune_history!(keep: 1)).to eq(1)
    expect(document.history_tracks.first.id).to eq(retained_id)
  end

  it 'does not delete history automatically on successful or failed saves' do
    document.update_attributes!(title: 'second')
    expect(document.update_attributes(title: nil)).to eq(false)
    expect(document.history_tracks.count).to eq(2)
  end

  it 'can explicitly discard all history and leaves the current document untouched' do
    document
    expect(document.prune_history!(keep: 0)).to eq(1)
    expect(document.history_tracks.count).to eq(0)
    expect(document.reload.title).to eq('first')
    expect(document.version).to eq(1)
  end

  it 'supports pruning the history of a destroyed document' do
    document.destroy
    expect(document.prune_history!(keep: 1)).to eq(1)
    expect(document.history_tracks.first.action).to eq('destroy')
  end

  it 'leaves a short or empty history unchanged' do
    expect(document.prune_history!(keep: 100)).to eq(0)
    document.prune_history!(keep: 0)
    expect(document.prune_history!(keep: 100)).to eq(0)
  end

  it 'rejects invalid retention counts without deleting history' do
    document
    [-1, nil, '2', 1.5, true].each do |keep|
      expect { document.prune_history!(keep: keep) }.to raise_error(ArgumentError)
    end
    expect(document.history_tracks.count).to eq(1)
  end

  it 'rejects unsaved documents even if their ids match an existing document' do
    unsaved = RetainedDocument.new(id: document.id, title: 'unsaved')
    expect { unsaved.prune_history!(keep: 0) }.to raise_error(ArgumentError)
    expect(document.history_tracks.count).to eq(1)
  end
end
