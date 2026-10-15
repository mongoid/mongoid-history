require 'spec_helper'

describe 'Obfuscating history values' do
  before do
    class SensitiveDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :s, as: :secret
      field :label
      field :details, type: Hash
      track_history modifier_field: nil, obfuscate: [:secret, 'details.token']
    end
  end

  after do
    Object.send(:remove_const, :SensitiveDocument)
  end

  let(:filtered) { Mongoid::History::Obfuscation::FILTERED }

  it 'records that a secret changed without persisting either value' do
    document = SensitiveDocument.create!(secret: 'old-secret', label: 'visible')
    create_track = document.history_tracks.last.reload
    expect(create_track.modified).to eq('s' => filtered, 'label' => 'visible')
    expect(create_track.obfuscated_fields).to eq(['s'])

    document.update_attributes!(secret: 'new-secret')
    track = document.history_tracks.last.reload
    expect(track.original).to eq('s' => filtered)
    expect(track.modified).to eq('s' => filtered)
    expect(track.action).to eq('update')
    expect(track.version).to eq(2)
    expect(document.reload.secret).to eq('new-secret')
    expect(Tracker.collection.find.to_a.inspect).not_to include('old-secret', 'new-secret')

    document.destroy
    expect(Tracker.where(action: 'destroy').last.reload.original['s']).to eq(filtered)
    expect(Tracker.collection.find.to_a.inspect).not_to include('old-secret', 'new-secret')
  end

  it 'filters nested hashes and every member of nested arrays without changing document values' do
    details = { 'token' => %w[secret-one secret-two], 'public' => 'visible' }
    document = SensitiveDocument.create!(details: details)
    track = document.history_tracks.last.reload
    expect(track.modified['details']).to eq('token' => filtered, 'public' => 'visible')
    expect(document.reload.details).to eq(details)

    snapshots = [{ 'items' => [{ 'token' => 'one' }, { 'token' => 'two' }] }]
    expect(Mongoid::History::Obfuscation.apply(snapshots, ['items.token'])).to eq(['items.token'])
    expect(snapshots.first['items'].map { |item| item['token'] }).to eq([filtered, filtered])
  end

  it 'preserves nils and does not mark unaffected tracks as obfuscated' do
    document = SensitiveDocument.create!(label: 'first')
    expect(document.history_tracks.last.reload.obfuscated_fields).to eq([])
    document.update_attributes!(label: 'second')
    track = document.history_tracks.last.reload
    expect(track.obfuscated_fields).to eq([])
    track.undo!
    expect(document.reload.label).to eq('first')
  end

  it 'filters symbol-keyed hashes before BSON converts the keys to strings' do
    document = SensitiveDocument.create!(details: { token: 'symbol-secret', public: 'visible' })
    track = document.history_tracks.last.reload
    expect(track.modified['details']['token']).to eq(filtered)
    expect(Tracker.collection.find.to_a.inspect).not_to include('symbol-secret')
    expect(document.reload.details.values).to include('symbol-secret')

    snapshots = [{ 'items' => [{ 'token' => 'string-one', token: 'symbol-one' }, { token: 'symbol-two' }] }]
    Mongoid::History::Obfuscation.apply(snapshots, ['items.token'])
    expect(snapshots.first['items'].map { |item| item[:token] }).to eq([filtered, filtered])
    expect(snapshots.first['items'].first['token']).to eq(filtered)
  end

  it 'blocks every undo/redo entry point even after reconfiguration' do
    document = SensitiveDocument.create!(secret: 'old-secret')
    create_track = document.history_tracks.last.reload
    document.update_attributes!(secret: 'new-secret')
    update_track = document.history_tracks.last.reload
    document.destroy
    destroy_track = Tracker.where(action: 'destroy').last.reload
    SensitiveDocument.track_history modifier_field: nil

    [create_track, update_track, destroy_track].each do |track|
      expect { track.undo! }.to raise_error(ArgumentError, /obfuscated values/)
      expect { track.redo! }.to raise_error(ArgumentError, /obfuscated values/)
      expect { track.undo_attr(nil) }.to raise_error(ArgumentError, /obfuscated values/)
      expect { track.redo_attr(nil) }.to raise_error(ArgumentError, /obfuscated values/)
    end
  end

  it 'keeps the existing defaults when obfuscation is not configured' do
    SensitiveDocument.track_history modifier_field: nil
    document = SensitiveDocument.create!(secret: 'visible-secret')
    track = document.history_tracks.last.reload
    expect(track.modified['s']).to eq('visible-secret')
    expect(track.obfuscated_fields).to eq([])
  end

  context 'with embedded aliases' do
    before do
      class SensitiveProfile
        include Mongoid::Document
        field :t, as: :token
        field :public_value
        embedded_in :sensitive_document
      end

      SensitiveDocument.embeds_one :profile, class_name: 'SensitiveProfile', store_as: :p
      SensitiveDocument.track_history on: [:label, { profile: %i[token public_value] }],
                                      modifier_field: nil, obfuscate: ['profile.token']
    end

    after do
      Object.send(:remove_const, :SensitiveProfile)
    end

    it 'filters create, nested update and destroy without leaking aliased fields' do
      document = SensitiveDocument.create!(profile: SensitiveProfile.new(token: 'old-token', public_value: 'visible'))
      expect(Tracker.collection.find.to_a.inspect).not_to include('old-token')
      document.profile.token = 'new-token'
      document.save!
      expect(document.reload.profile.token).to eq('new-token')
      expect(Tracker.collection.find.to_a.inspect).not_to include('old-token', 'new-token')
      document.destroy
      expect(Tracker.collection.find.to_a.inspect).not_to include('old-token', 'new-token')
      expect(Tracker.where(action: 'destroy').last.reload.obfuscated_fields).not_to be_empty
    end
  end
end
