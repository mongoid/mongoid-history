require 'spec_helper'

describe 'Recorded attribute reconstruction' do
  before do
    class HistoryVersionDocument
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :headline, as: :title, type: String
      field :data, type: Hash
      field :tags, type: Array
      field :hidden, type: String
      embeds_many :entries, class_name: 'HistoryVersionEntry'
      track_history on: %i[title data tags], modifier_field: nil, version_field: :revision, track_blank_changes: true
    end

    class HistoryVersionEntry
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      embedded_in :history_version_document
      track_history on: [:title], scope: :history_version_document, modifier_field: nil
    end
  end

  after do
    Object.send(:remove_const, :HistoryVersionDocument)
    Object.send(:remove_const, :HistoryVersionEntry)
  end

  let(:document) do
    HistoryVersionDocument.create!(title: 'First', data: { 'a' => 1, 'b' => 2 }, tags: %w[one two], hidden: 'private')
  end

  def record_times
    document.history_tracks.each do |track|
      track.update_attribute(:created_at, Time.utc(2020, 1, track.version))
    end
  end

  it 'reconstructs recorded database keys without copying current or untracked attributes' do
    document.update_attributes!(title: 'Second', hidden: 'new private')
    document.update_attributes!(title: 'Third')
    document.reload
    count = document.history_tracks.count

    first = document.attributes_at_version(1)
    expect(first).to eq('headline' => 'First', 'data' => { 'a' => 1, 'b' => 2 }, 'tags' => %w[one two])
    expect(document.attributes_at_version(2)['headline']).to eq('Second')
    expect(document.attributes_at_version(3)['headline']).to eq('Third')
    expect(document.title).to eq('Third')
    expect(document.changed?).to be false
    expect(document.history_tracks.count).to eq(count)
    first['data']['a'] = 'mutated'
    expect(document.attributes_at_version(1)['data']['a']).to eq(1)
    expect(document.attributes_at_version(0)).to be_nil
  end

  it 'replays hash, array and nil changes from persisted tracks' do
    document.update_attributes!(data: { 'a' => 3 }, tags: %w[two three])
    document.update_attributes!(title: nil)
    document.reload
    expect(document.attributes_at_version(1)['data']).to eq('a' => 1, 'b' => 2)
    expect(document.attributes_at_version(2)['data']).to eq('a' => 3)
    expect(document.attributes_at_version(2)['tags']).to eq(%w[two three])
    expect(document.attributes_at_version(3)).not_to have_key('headline')
  end

  it 'uses inclusive timestamp boundaries, including before creation and after destruction' do
    document.update_attributes!(title: 'Second')
    document.destroy
    record_times

    expect(document.attributes_at(Time.utc(2019))).to be_nil
    expect(document.attributes_at(Time.utc(2020, 1, 1))['headline']).to eq('First')
    expect(document.attributes_at(Time.utc(2020, 1, 2))['headline']).to eq('Second')
    expect(document.attributes_at(Time.utc(2020, 1, 2, 23))['headline']).to eq('Second')
    expect(document.attributes_at(Time.utc(2020, 1, 3))).to be_nil
    expect(document.attributes_at(Time.utc(2021))).to be_nil
    expect(document.attributes_at_version(2)['headline']).to eq('Second')
    expect(document.attributes_at_version(3)).to be_nil
  end

  it 'orders changes at an identical timestamp by version' do
    document.update_attributes!(title: 'Second')
    document.history_tracks.each { |track| track.update_attribute(:created_at, Time.utc(2020)) }
    expect(document.attributes_at(Time.utc(2020))['headline']).to eq('Second')
    expect(document.attributes_at(Time.utc(2020).in_time_zone('UTC'))['headline']).to eq('Second')
  end

  it 'rejects invalid selectors and unrecorded future versions' do
    [-1, 1.0, '1', nil].each do |version|
      expect { document.attributes_at_version(version) }.to raise_error(ArgumentError)
    end
    expect { document.attributes_at('2020-01-01') }.to raise_error(ArgumentError)
    expect { document.attributes_at_version(2) }.to raise_error(Mongoid::History::IncompleteHistory)
  end

  it 'raises when the create track or any intervening track is missing' do
    document.update_attributes!(title: 'Second')
    document.update_attributes!(title: 'Third')
    document.history_tracks.where(version: 2).first.destroy
    expect { document.attributes_at_version(1) }.to raise_error(Mongoid::History::IncompleteHistory)
    document.history_tracks.where(version: 1).first.destroy
    expect { document.attributes_at(Time.now) }.to raise_error(Mongoid::History::IncompleteHistory)
  end

  it 'raises when the last retained track is older than the document version' do
    document.update_attributes!(title: 'Second')
    document.history_tracks.where(version: 2).first.destroy
    expect { document.attributes_at_version(1) }.to raise_error(Mongoid::History::IncompleteHistory)
  end

  it 'raises when history is empty or timestamps are inconsistent' do
    expect { HistoryVersionDocument.new.attributes_at_version(0) }.to raise_error(Mongoid::History::IncompleteHistory)
    document.update_attributes!(title: 'Second')
    document.history_tracks.where(version: 1).first.update_attribute(:created_at, Time.now + 3600)
    expect { document.attributes_at_version(1) }.to raise_error(Mongoid::History::IncompleteHistory)
  end

  it 'raises rather than inventing a baseline when creation was not tracked' do
    untracked = HistoryVersionDocument.disable_tracking { HistoryVersionDocument.create!(title: 'Unknown') }
    untracked.update_attributes!(title: 'Known')
    expect { untracked.attributes_at_version(1) }.to raise_error(Mongoid::History::IncompleteHistory)
  end

  it 'can replay an embedded receiver after it is destroyed without changing its parent' do
    entry = document.entries.create!(title: 'Entry')
    entry.update_attributes!(title: 'Changed entry')
    entry.destroy
    expect(entry.attributes_at_version(1)).to eq('title' => 'Entry')
    expect(entry.attributes_at_version(2)).to eq('title' => 'Changed entry')
    expect(entry.attributes_at_version(3)).to be_nil
    expect(document.reload.entries).to be_empty
  end

  it 'raises on duplicate versions instead of silently choosing a value' do
    track = document.history_tracks.first
    document.class.tracker_class.create!(track.attributes.except('_id', 'created_at', 'updated_at'))
    expect { document.attributes_at_version(1) }.to raise_error(Mongoid::History::IncompleteHistory)
  end
end
