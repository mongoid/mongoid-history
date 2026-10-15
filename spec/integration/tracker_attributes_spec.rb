require 'spec_helper'

describe 'Model-specific tracker attributes' do
  before do
    class MetadataTracker
      include Mongoid::History::Tracker

      field :request_id, type: String
      field :source, type: String
      field :operation, type: String
      attr_accessor :request_id_at_creation

      before_create { self.request_id_at_creation = request_id }
    end

    class MetadataDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      attr_accessor :request_id, :extra_tracker_attributes

      track_history on: [:title], modifier_field: nil, tracker_class_name: :metadata_tracker,
                    tracker_attributes_method: :audit_context

      private

      def audit_context(action)
        return extra_tracker_attributes unless extra_tracker_attributes.nil?

        { 'request_id' => request_id, source: 'document', operation: action.to_s }
      end
    end

    class OtherMetadataDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      track_history on: [:title], modifier_field: nil, tracker_class_name: :metadata_tracker,
                    tracker_attributes_method: :audit_context

      def audit_context(action)
        { source: 'other document', operation: action.to_s }
      end
    end
  end

  after do
    %i[MetadataDocument OtherMetadataDocument MetadataTracker].each do |name|
      Object.send(:remove_const, name)
    end
  end

  let(:document) { MetadataDocument.create!(title: 'first', request_id: 'create-request') }

  it 'supplies custom tracker attributes before tracker callbacks run' do
    callback_request_id = nil
    allow(MetadataTracker).to receive(:create!).and_wrap_original do |method, attributes|
      method.call(attributes).tap { |track| callback_request_id = track.request_id_at_creation }
    end

    expect(document.history_tracks.first.request_id).to eq('create-request')
    expect(callback_request_id).to eq('create-request')
    expect(document.history_tracks.first.operation).to eq('create')
  end

  it 'evaluates metadata afresh for each tracked create, update and destroy' do
    document.request_id = 'update-request'
    document.update_attributes!(title: 'second')
    document.request_id = 'destroy-request'
    document.destroy

    expect(document.history_tracks.map(&:request_id)).to eq(%w[create-request update-request destroy-request])
    expect(document.history_tracks.map(&:operation)).to eq(%w[create update destroy])
    expect(document.history_tracks.map(&:source).uniq).to eq(['document'])
  end

  it 'allows different models to populate the same tracker without tracker dispatch callbacks' do
    document
    other = OtherMetadataDocument.create!(title: 'other')
    expect(document.history_tracks.first.source).to eq('document')
    expect(other.history_tracks.first.source).to eq('other document')
  end

  it 'does not treat metadata as tracked model changes or create metadata-only revisions' do
    document.request_id = 'another-request'
    expect { document.save! }.not_to change(MetadataTracker, :count)
    document.update_attributes!(title: 'second')
    track = document.history_tracks.last
    expect(track.original).to eq('title' => 'first')
    expect(track.modified).to eq('title' => 'second')
    expect(track.request_id).to eq('another-request')
    track.undo!
    expect(document.reload.title).to eq('first')
  end

  it 'rejects attempts to replace canonical history fields without changing persisted data' do
    document
    %w[_id id _type association_chain scope version action original modified modifier modifier_id trackable created_at updated_at].each do |key|
      document.extra_tracker_attributes = { key => 'replacement' }
      expect { document.update_attributes!(title: 'second') }.to raise_error(ArgumentError, /reserved/)
      expect(document.version).to eq(1)
      expect(document.reload.title).to eq('first')
      expect(document.history_tracks.count).to eq(1)
    end
  end

  it 'requires the configured method to return a hash' do
    document.extra_tracker_attributes = 'invalid'
    expect { document.update_attributes!(title: 'second') }.to raise_error(ArgumentError, /Hash/)
    expect(document.reload.title).to eq('first')
    expect(document.history_tracks.count).to eq(1)
  end

  it 'discards memoized changes after a metadata error so a retry records the actual edit' do
    document.extra_tracker_attributes = 'invalid'
    expect { document.update_attributes!(title: 'rejected') }.to raise_error(ArgumentError)
    document.extra_tracker_attributes = nil
    document.update_attributes!(title: 'accepted')
    expect(document.history_tracks.last.original).to eq('title' => 'first')
    expect(document.history_tracks.last.modified).to eq('title' => 'accepted')
    expect(document.history_tracks.last.version).to eq(2)
  end

  it 'does not invoke the metadata hook when tracking is disabled' do
    document
    expect(document).not_to receive(:audit_context)
    MetadataDocument.disable_tracking { document.update_attributes!(title: 'untracked') }
    expect(document.history_tracks.count).to eq(1)
  end

  it 'does not invoke the metadata hook for a metadata-only save' do
    document
    expect(document).not_to receive(:audit_context)
    document.request_id = 'changed-context'
    document.save!
    expect(document.history_tracks.count).to eq(1)
  end
end
