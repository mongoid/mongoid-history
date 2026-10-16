require 'spec_helper'

describe 'History configuration' do
  before do
    @tracker_class_name = Mongoid::History.tracker_class_name
    stub_const('HistoryConfiguration', Module.new)

    module HistoryConfiguration
      class Author
        include Mongoid::Document
      end

      class Tracker
        include Mongoid::History::Tracker
      end

      class Article
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :title, type: String
        track_history on: :fields, modifier_field: nil,
                      tracker_class_name: 'HistoryConfiguration::Tracker',
                      version_field: :_version
      end
    end
  end

  after do
    HistoryConfiguration::Tracker.delete_all
    Mongoid::History.tracker_class_name = @tracker_class_name
    Object.send(:remove_const, :AutoloadHistoryTracker) if Object.const_defined?(:AutoloadHistoryTracker)
  end

  it 'does not redeclare a history-owned version field on repeated declarations' do
    version_field = HistoryConfiguration::Article.fields['_version']
    HistoryConfiguration::Article.track_history on: :fields

    expect(HistoryConfiguration::Article.fields['_version']).to equal(version_field)
    expect(HistoryConfiguration::Article.fields).not_to have_key('version')
  end

  it 'refreshes prepared options and field caches when tracking is redeclared' do
    klass = HistoryConfiguration::Article
    expect(klass.tracked_fields).to eq(['title'])
    klass.field :body, type: String
    klass.track_history on: :fields

    article = klass.create!(title: 'First', body: 'Body')
    expect(article.history_tracks.count).to eq(1)
    expect(article.history_tracks.first.modified).to include('title' => 'First', 'body' => 'Body')
    article.update_attributes!(body: 'Updated')
    expect(article.history_tracks.count).to eq(2)
    expect(article.history_tracks.last.modified).to include('body' => 'Updated')
  end

  it 'refreshes cached formats when tracking is redeclared' do
    klass = HistoryConfiguration::Article
    expect(klass.field_formats).to eq({})
    formatter = proc { |values| values.map { |value| value&.upcase } }
    klass.track_history format: { title: formatter }

    expect(klass.field_formats).to eq('title' => formatter)
    expect(klass.create!(title: 'First').history_tracks.first.modified).to include('title' => 'FIRST')
  end

  it 'keeps inherited version settings when subclasses declare additional fields' do
    stub_const('HistoryConfiguration::SpecialArticle', Class.new(HistoryConfiguration::Article))
    klass = HistoryConfiguration::SpecialArticle
    klass.field :body, type: String
    klass.track_history on: :fields

    article = klass.create!(title: 'First', body: 'Body')
    article.update_attributes!(body: 'Updated')

    expect(article._version).to eq(2)
    expect(article.attributes).not_to have_key('version')
    expect(article.history_tracks.map(&:version)).to eq([1, 2])
    expect(article.history_tracks.last.trackable).to eq(article)
  end

  it 'inherits a custom version field without redeclaring tracking' do
    stub_const('HistoryConfiguration::SpecialArticle', Class.new(HistoryConfiguration::Article))
    article = HistoryConfiguration::SpecialArticle.create!(title: 'First')
    article.update_attributes!(title: 'Second')

    expect(article._version).to eq(2)
    expect(article.attributes).not_to have_key('version')
    expect(article.history_tracks.map(&:version)).to eq([1, 2])
  end

  it 'supports namespaced trackers and trackables through create, update and undo' do
    article = HistoryConfiguration::Article.create!(title: 'First')
    article.update_attributes!(title: 'Second')
    track = HistoryConfiguration::Tracker.last

    expect(track.trackable).to eq(article)
    expect(track.association_chain.first['name']).to eq('HistoryConfiguration::Article')
    article.undo!
    expect(article.reload.title).to eq('First')
  end

  it 'supports a namespaced modifier configured before model declarations' do
    Mongoid::History.modifier_class_name = 'HistoryConfiguration::Author'
    stub_const('HistoryConfiguration::AuthoredTracker', Class.new)
    HistoryConfiguration::AuthoredTracker.class_eval do
      include Mongoid::History::Tracker
    end
    HistoryConfiguration::Article.track_history modifier_field: :author,
                                                tracker_class_name: 'HistoryConfiguration::AuthoredTracker'
    author = HistoryConfiguration::Author.create!
    article = HistoryConfiguration::Article.create!(title: 'First', author: author)

    expect(article.history_tracks.first.modifier).to eq(author)
  end

  it 'tracks without a User model when modifier_field is nil' do
    article = HistoryConfiguration::Article.create!(title: 'First')

    expect(article.history_tracks.first.modifier).to be_nil
  end

  it 'uses an explicit global tracker regardless of which tracker was loaded first' do
    Mongoid::History.tracker_class_name = 'HistoryConfiguration::Tracker'
    HistoryConfiguration::Article.track_history tracker_class_name: nil

    expect(HistoryConfiguration::Article.tracker_class).to eq(HistoryConfiguration::Tracker)
    expect(HistoryConfiguration::Article.create!(title: 'First').history_tracks.count).to eq(1)
  end

  it 'explains how to configure a tracker when none has been loaded' do
    Mongoid::History.tracker_class_name = nil
    HistoryConfiguration::Article.track_history tracker_class_name: nil

    expect { HistoryConfiguration::Article.tracker_class }
      .to raise_error(ArgumentError, /Mongoid::History.tracker_class_name/)
  end

  it 'accepts an explicit tracker class with no persisted history' do
    HistoryConfiguration::Article.track_history tracker_class_name: HistoryConfiguration::Tracker

    expect(HistoryConfiguration::Tracker.count).to eq(0)
    expect(HistoryConfiguration::Article.tracker_class).to eq(HistoryConfiguration::Tracker)
    expect(HistoryConfiguration::Article.create!(title: 'First').history_tracks.count).to eq(1)
  end

  it 'autoloads an explicitly configured tracker before that model has been loaded' do
    Object.autoload(:AutoloadHistoryTracker, File.expand_path('../fixtures/autoload_history_tracker.rb', __dir__))
    Mongoid::History.tracker_class_name = :autoload_history_tracker
    HistoryConfiguration::Article.track_history tracker_class_name: nil

    expect(HistoryConfiguration::Article.create!(title: 'First').history_tracks.count).to eq(1)
    expect(HistoryConfiguration::Article.tracker_class).to eq(AutoloadHistoryTracker)
  end

  it 'returns fresh history when another instance records a change' do
    article = HistoryConfiguration::Article.create!(title: 'First')
    criteria = article.history_tracks
    expect(article.history_tracks.to_a.size).to eq(1)
    HistoryConfiguration::Article.find(article.id).update_attributes!(title: 'Second')

    expect(article.history_tracks).not_to equal(criteria)
    expect(article.history_tracks.to_a.size).to eq(2)
  end

  it 'does not reuse a tracker payload prepared for a different action' do
    article = HistoryConfiguration::Article.new(title: 'First')
    created = article.send(:history_tracker_attributes, :create)
    destroyed = article.send(:history_tracker_attributes, :destroy)

    expect(created[:modified]).to include('title' => 'First')
    expect(destroyed[:original]).to include('title' => 'First')
    expect(destroyed[:modified]).to be_empty
  end
end
