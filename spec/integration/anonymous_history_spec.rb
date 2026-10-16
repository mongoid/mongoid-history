require 'spec_helper'

describe 'Anonymous history suppression' do
  before do
    class User
      include Mongoid::Document
    end

    class AnonymousHistoryTracker
      include Mongoid::History::Tracker
    end
    Mongoid::History.tracker_class_name = 'AnonymousHistoryTracker'

    class AnonymousHistoryPost
      include Mongoid::Document
      include Mongoid::History::Trackable
      field :title, type: String
      track_history modifier_field_optional: true
    end
  end

  after do
    AnonymousHistoryTracker.delete_all
    %i[User AnonymousHistoryPost AnonymousHistoryTracker AnonymousHistoryContainer
       AnonymousHistoryEntry AnonymousDefaultPost].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end
  end

  it 'retains anonymous history by default' do
    post = AnonymousHistoryPost.create!(title: 'Anonymous')
    expect(post.history_tracks.count).to eq(1)
    expect(post.history_tracks.first.modifier).to be_nil
  end

  it 'skips anonymous create, update and destroy without advancing versions' do
    AnonymousHistoryPost.track_history track_without_modifier: false
    post = AnonymousHistoryPost.create!(title: 'First')
    post.update_attributes!(title: 'Second')
    expect(post.reload.version).to be_nil
    expect(post.history_tracks.count).to eq(0)
    post.destroy
    expect(AnonymousHistoryTracker.count).to eq(0)
  end

  it 'records changes with an explicitly assigned modifier' do
    AnonymousHistoryPost.track_history track_without_modifier: false
    actor = User.create!
    post = AnonymousHistoryPost.create!(title: 'First', modifier: actor)
    post.update_attributes!(title: 'Second')
    expect(post.history_tracks.map(&:modifier)).to eq([actor, actor])
    expect(post.reload.version).to eq(2)
  end

  it 'uses a definition-time global default while allowing explicit model overrides' do
    Mongoid::History.track_without_modifier = false
    class AnonymousDefaultPost
      include Mongoid::Document
      include Mongoid::History::Trackable
      field :title, type: String
      track_history modifier_field_optional: true
    end
    expect(AnonymousDefaultPost.create!(title: 'Skipped').history_tracks.count).to eq(0)
    expect(AnonymousHistoryPost.create!(title: 'Existing model').history_tracks.count).to eq(1)
    AnonymousDefaultPost.track_history track_without_modifier: true
    expect(AnonymousDefaultPost.create!(title: 'Tracked').history_tracks.count).to eq(1)
  end

  it 'skips history when the modifier association is disabled' do
    AnonymousHistoryPost.track_history modifier_field: nil, track_without_modifier: false
    post = AnonymousHistoryPost.create!(title: 'First')
    post.update_attributes!(title: 'Second')
    expect(post.history_tracks.count).to eq(0)
  end

  it 'does not bypass required modifier validation' do
    AnonymousHistoryPost.track_history track_without_modifier: false
    AnonymousHistoryPost.validates :modifier, presence: true
    expect { AnonymousHistoryPost.create!(title: 'Invalid') }.to raise_error(Mongoid::Errors::Validations)
    expect(AnonymousHistoryTracker.count).to eq(0)
  end

  it 'supports anonymous embedded history suppression without skipping validation' do
    class AnonymousHistoryContainer
      include Mongoid::Document
      embeds_many :anonymous_history_entries
    end

    class AnonymousHistoryEntry
      include Mongoid::Document
      include Mongoid::History::Trackable
      embedded_in :anonymous_history_container
      field :title, type: String
      validates :title, presence: true
      track_history modifier_field_optional: true, track_without_modifier: false
    end
    parent = AnonymousHistoryContainer.create!
    expect { parent.anonymous_history_entries.create!(title: '') }.to raise_error(Mongoid::Errors::Validations)
    entry = parent.anonymous_history_entries.create!(title: 'First')
    expect(entry.history_tracks.count).to eq(0)
    expect(entry.version).to be_nil
    actor = User.create!
    entry.update_attributes!(title: 'Second', modifier: actor)
    expect(entry.history_tracks.first.modifier).to eq(actor)
    expect(entry.version).to eq(1)
  end
end
