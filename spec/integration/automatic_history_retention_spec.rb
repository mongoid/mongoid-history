require 'spec_helper'

describe 'Automatic history retention' do
  before do
    class RetentionParent
      include Mongoid::Document

      field :title, type: String
      attr_accessor :fail_after_save

      embeds_many :limited_children, cascade_callbacks: true
      after_save { raise 'parent save failed' if fail_after_save }
    end

    class LimitedChild
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      embedded_in :retention_parent
      track_history on: [:title], modifier_field: nil, scope: :retention_parent, max_history: 1
    end

    class LimitedDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      attr_accessor :fail_after_save, :fail_after_destroy

      validates :title, presence: true
      after_save { raise 'save failed' if fail_after_save }
      after_destroy { raise 'destroy failed' if fail_after_destroy }
      track_history on: [:title], modifier_field: nil, max_history: 2
    end

    class ZeroHistoryDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      track_history on: [:title], modifier_field: nil, max_history: 0
    end
  end

  after do
    %i[RetentionParent LimitedChild LimitedDocument ZeroHistoryDocument].each do |name|
      Object.send(:remove_const, name)
    end
  end

  let(:document) { LimitedDocument.create!(title: 'first') }

  it 'automatically retains the configured count after successful creates, updates and destroys' do
    document.update_attributes!(title: 'second')
    document.update_attributes!(title: 'third')
    expect(document.history_tracks.map(&:version)).to eq([2, 3])
    document.destroy
    expect(document.history_tracks.map(&:version)).to eq([3, 4])
    expect(document.history_tracks.last.action).to eq('destroy')
  end

  it 'does not prune on failed validation' do
    document.update_attributes!(title: 'second')
    expect(document.update_attributes(title: nil)).to eq(false)
    expect(document.history_tracks.map(&:version)).to eq([1, 2])
  end

  it 'does not prune when a save callback raises' do
    document.update_attributes!(title: 'second')
    document.fail_after_save = true
    expect { document.update_attributes!(title: 'third') }.to raise_error('save failed')
    expect(document.history_tracks.where(:version.in => [1, 2]).count).to eq(2)
    expect(document.instance_variable_get(:@mongoid_history_retention_frames)).to be_nil
  end

  it 'does not prune when building the database update raises' do
    document.update_attributes!(title: 'second')
    allow(document).to receive(:atomic_updates).and_raise('write failed')
    expect { document.update_attributes!(title: 'third') }.to raise_error('write failed')
    expect(document.history_tracks.where(:version.in => [1, 2]).count).to eq(2)
    expect(document.instance_variable_get(:@mongoid_history_retention_frames)).to be_nil
  end

  it 'does not prune when destruction callbacks raise' do
    document.update_attributes!(title: 'second')
    document.fail_after_destroy = true
    expect { document.destroy }.to raise_error('destroy failed')
    expect(document.history_tracks.where(:version.in => [1, 2]).count).to eq(2)
  end

  it 'discards queued embedded pruning when an untracked parent save later raises' do
    parent = RetentionParent.create!(title: 'parent')
    child = parent.limited_children.create!(title: 'first')
    first_id = child.history_tracks.first.id
    child.title = 'second'
    parent.fail_after_save = true
    expect { parent.save! }.to raise_error('parent save failed')
    expect(Tracker.where(id: first_id).count).to eq(1)
    expect(parent.instance_variable_get(:@mongoid_history_retention_frames)).to be_nil
  end

  it 'prunes an embedded history after its parent save succeeds' do
    parent = RetentionParent.create!(title: 'parent')
    child = parent.limited_children.create!(title: 'first')
    child.title = 'second'
    parent.save!
    expect(child.history_tracks.map(&:version)).to eq([2])
  end

  it 'prunes standalone embedded writes without touching sibling history' do
    parent = RetentionParent.create!(title: 'parent')
    child = parent.limited_children.create!(title: 'first')
    sibling = parent.limited_children.create!(title: 'sibling')
    child.update_attributes!(title: 'second')
    expect(child.history_tracks.map(&:version)).to eq([2])
    expect(sibling.history_tracks.map(&:version)).to eq([1])
  end

  it 'does not run automatic retention for disabled tracking' do
    document.update_attributes!(title: 'second')
    expect(document).not_to receive(:prune_history!)
    LimitedDocument.disable_tracking { document.update_attributes!(title: 'third') }
    expect(document.history_tracks.count).to eq(2)
  end

  it 'does not prune on an update containing no tracked changes' do
    document
    expect(document).not_to receive(:prune_history!)
    document.save!
  end

  it 'propagates retention failure without removing the successfully persisted edit' do
    document.update_attributes!(title: 'second')
    allow(document).to receive(:prune_history!).and_raise('retention failed')
    expect { document.update_attributes!(title: 'third') }.to raise_error('retention failed')
    expect(document.reload.title).to eq('third')
    expect(document.version).to eq(3)
    expect(document.history_tracks.map(&:version)).to eq([1, 2, 3])
    expect(document.instance_variable_get(:@mongoid_history_retention_frames)).to be_nil
  end

  it 'allows zero retention without resetting the persisted history version' do
    zero = ZeroHistoryDocument.create!(title: 'first')
    expect(zero.history_tracks.count).to eq(0)
    zero.update_attributes!(title: 'second')
    expect(zero.history_tracks.count).to eq(0)
    expect(zero.reload.version).to eq(2)
  end

  it 'validates the option when configuring a trackable model' do
    [-1, false, '2', 1.5].each do |limit|
      expect { Mongoid::History::Options.new(LimitedDocument, max_history: limit) }
        .to raise_error(ArgumentError, /max_history/)
    end
    expect(Mongoid::History::Options.new(LimitedDocument).options[:max_history]).to be_nil
  end
end
