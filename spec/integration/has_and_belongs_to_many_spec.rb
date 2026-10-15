require 'spec_helper'

describe 'Saved HABTM foreign key history' do
  before do
    class ReferenceAudit
      include Mongoid::History::Tracker
    end

    class ReferenceTag
      include Mongoid::Document
      field :name, type: String
    end

    class ReferenceArticle
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      has_and_belongs_to_many :tags, class_name: 'ReferenceTag', inverse_of: nil
      has_and_belongs_to_many :reviewers, class_name: 'ReferenceTag', inverse_of: nil, foreign_key: :reviewer_keys
      validates_presence_of :title
      track_history on: [:tags], modifier_field: nil, tracker_class_name: ReferenceAudit
    end

    class ReferenceReviewArticle
      include Mongoid::Document
      include Mongoid::History::Trackable

      track_history on: :referenced_relations, modifier_field: nil, tracker_class_name: ReferenceAudit
      has_and_belongs_to_many :reviewers, class_name: 'ReferenceTag', inverse_of: nil, foreign_key: :reviewer_keys
    end
  end

  after do
    Object.send(:remove_const, :ReferenceArticle)
    Object.send(:remove_const, :ReferenceReviewArticle)
    Object.send(:remove_const, :ReferenceTag)
    Object.send(:remove_const, :ReferenceAudit)
  end

  let(:tag) { ReferenceTag.create!(name: 'First') }
  let(:another_tag) { ReferenceTag.create!(name: 'Second') }
  let(:article) { ReferenceArticle.create!(title: 'Article', tag_ids: [tag.id]) }

  it 'tracks creation by relation name as stored IDs, not target documents' do
    expect(article.history_tracks.first.modified).to eq('tag_ids' => [tag.id])
    expect(article.history_tracks.first.original).to eq({})
  end

  it 'tracks saved additions and removals with persisted, increasing versions' do
    article.update_attributes!(tag_ids: [tag.id, another_tag.id])
    addition = article.history_tracks.last
    expect(addition.original['tag_ids']).to eq([tag.id])
    expect(addition.modified['tag_ids']).to eq([tag.id, another_tag.id])
    article.update_attributes!(tag_ids: [another_tag.id])
    removal = article.history_tracks.last
    expect(removal.original['tag_ids']).to eq([tag.id, another_tag.id])
    expect(removal.modified['tag_ids']).to eq([another_tag.id])
    expect(article.reload.version).to eq(3)
    expect(article.history_tracks.map(&:version)).to eq([1, 2, 3])
  end

  it 'supports undo and redo after clearing references' do
    article.update_attributes!(tag_ids: [])
    track = article.history_tracks.last
    expect(article.reload.tag_ids).to eq([])
    track.undo!
    expect(article.reload.tag_ids).to eq([tag.id])
    track.redo!
    expect(article.reload.tag_ids).to eq([])
  end

  it 'does not track other associations to the same target class' do
    article.update_attributes!(reviewer_keys: [another_tag.id])
    expect(article.history_tracks.count).to eq(1)
    expect(article.reload.reviewer_keys).to eq([another_tag.id])
  end

  it 'does not record failed validations' do
    expect { article.update_attributes!(title: nil, tag_ids: []) }.to raise_error(Mongoid::Errors::Validations)
    expect(article.reload.tag_ids).to eq([tag.id])
    expect(article.history_tracks.count).to eq(1)
  end

  it 'honors disabled tracking' do
    article
    ReferenceArticle.disable_tracking { article.update_attributes!(tag_ids: []) }
    expect(article.history_tracks.count).to eq(1)
  end

  it 'supports selecting all HABTM associations, including custom foreign keys' do
    options = Mongoid::History::Options.new(ReferenceArticle, on: :referenced_relations).prepared
    expect(options[:fields]).to match_array(%w[tag_ids reviewer_keys])
    expect(options[:dynamic]).to eq([])
  end

  it 'tracks and undoes saved custom foreign keys declared after track_history' do
    review_article = ReferenceReviewArticle.create!(reviewer_keys: [tag.id])
    review_article.update_attributes!(reviewer_keys: [another_tag.id])
    track = review_article.history_tracks.last
    expect(track.original['reviewer_keys']).to eq([tag.id])
    expect(track.modified['reviewer_keys']).to eq([another_tag.id])
    track.undo!
    expect(review_article.reload.reviewer_keys).to eq([tag.id])
  end

  it 'normalizes relation names in exclusions and formats' do
    options = Mongoid::History::Options.new(
      ReferenceArticle, on: :referenced_relations, except: [:reviewers], format: { tags: proc { |value| value } }
    ).prepared
    expect(options[:fields]).to eq(['tag_ids'])
    expect(options[:except]).to eq(['reviewer_keys'])
    expect(options[:format].keys).to eq(['tag_ids'])
  end

  it 'does not install callbacks or pretend atomic proxy writes run document callbacks' do
    article.tags << another_tag
    expect(article.reload.tag_ids).to match_array([tag.id, another_tag.id])
    expect(article.history_tracks.count).to eq(1)
  end

  it 'keeps existing all-field and explicit foreign-key selectors' do
    expect(Mongoid::History::Options.new(ReferenceArticle).prepared[:fields]).to include('tag_ids', 'reviewer_keys')
    options = Mongoid::History::Options.new(ReferenceArticle, on: :tag_ids).prepared
    expect(options[:fields]).to eq(['tag_ids'])
  end
end
