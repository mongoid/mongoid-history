require 'spec_helper'
require 'money'
require 'money-rails/mongoid/money'

describe 'Custom serialized history values' do
  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  before do
    class PricedDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :amount, type: Money
      field :day, type: Date
      field :label, type: String
      track_history modifier_field: nil
    end
  end

  after do
    Object.send(:remove_const, :PricedDocument) if Object.const_defined?(:PricedDocument)
  end

  let(:amount) { Money.new(20_000, 'USD') }

  it 'keeps BSON storage unchanged and offers typed values after reload' do
    document = PricedDocument.create!(amount: amount, day: Date.new(2026, 10, 15), label: 'first')
    track = document.history_tracks.last.reload

    expect(document.reload.amount).to eq(amount)
    expect(track.database_modified['amount']).to be_a(Hash)
    expect(track.modified['amount']).to eq(amount)
    expect(track.modified['day']).to eq(document.day)
    expect(track.modified['label']).to eq('first')
    expect(track.modified['day']).to be_a(Date)
    expect(track.database_modified['day']).to be_a(Time)
    expect(track.attributes['modified']['amount']).to be_a(Hash)
    expect(track.tracked_changes['amount'][:to]).to eq(amount)
    expect(track.affected['amount']).to eq(amount)
    track.save!
    expect(track.reload.database_modified['amount']).to be_a(Hash)
    expect(track.modified['amount']).to eq(amount)
  end

  it 'reads both sides of updates and can undo and redo serialized fields' do
    document = PricedDocument.create!(amount: amount)
    replacement = Money.new(35_000, 'EUR')
    document.update_attributes!(amount: replacement)
    track = document.history_tracks.last.reload

    expect(track.original['amount']).to eq(amount)
    expect(track.modified['amount']).to eq(replacement)
    expect(track.database_original['amount']).to be_a(Hash)
    expect(track.database_modified['amount']).to be_a(Hash)
    track.undo!
    expect(document.reload.amount).to eq(amount)
    track.redo!
    expect(document.reload.amount).to eq(replacement)
  end

  it 'reads destroyed records without looking up the document' do
    document = PricedDocument.create!(amount: amount)
    document.destroy
    track = Tracker.where(action: 'destroy').last.reload

    expect(track.original['amount']).to eq(amount)
    expect(track.modified).to eq({})
    track.undo!
    expect(PricedDocument.find(document.id).amount).to eq(amount)
    track.redo!
    expect(PricedDocument.where(_id: document.id).count).to eq(0)
  end

  it 'preserves nils and unknown dynamic fields' do
    track = Tracker.new(association_chain: [{ 'name' => 'PricedDocument' }],
                        modified: { 'amount' => nil, 'unknown' => { 'value' => 'raw' } })
    expect(track.modified).to eq('amount' => nil, 'unknown' => { 'value' => 'raw' })
    track.modified['unknown']['value'].replace('changed')
    expect(track.modified['unknown']['value']).to eq('raw')
  end

  it 'keeps raw history accessible when the model definition is unavailable' do
    document = PricedDocument.create!(amount: amount)
    track = document.history_tracks.last.reload
    Object.send(:remove_const, :PricedDocument)

    expect(track.database_modified['amount']).to be_a(Hash)
    expect { track.modified }.to raise_error(NameError)
  end

  context 'with embedded documents' do
    before do
      class PricedLine
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :a, as: :amount, type: Money
        embedded_in :priced_document
        track_history modifier_field: nil
      end

      PricedDocument.embeds_many :priced_lines, class_name: 'PricedLine'
      PricedDocument.track_history on: [:amount, { priced_lines: :amount }], modifier_field: nil
    end

    after do
      Object.send(:remove_const, :PricedLine)
    end

    it 'uses the embedded class and its database field names' do
      document = PricedDocument.create!(priced_lines: [PricedLine.new(amount: amount)])
      root_track = document.history_tracks.first.reload
      expect(root_track.modified['priced_lines'].first['a']).to eq(amount)

      document.priced_lines.create!(amount: amount)
      child_track = Tracker.where('association_chain.name' => 'priced_lines').first.reload
      expect(child_track.modified['a']).to eq(amount)
      expect(child_track.database_modified['a']).to be_a(Hash)
    end
  end
end
