require 'spec_helper'

describe 'Custom history association names' do
  before do
    class AssociationAudit
      include Mongoid::History::Tracker
    end

    class AssociationArticle
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      track_history modifier_field: nil, tracker_class_name: AssociationAudit, history_method: :audits
    end

    class AssociationReservedArticle
      include Mongoid::Document
      include Mongoid::History::Trackable
    end
  end

  after do
    Object.send(:remove_const, :AssociationArticle)
    Object.send(:remove_const, :AssociationReservedArticle)
    Object.send(:remove_const, :AssociationAudit)
  end

  it 'aliases the configured tracker criteria without removing history_tracks' do
    article = AssociationArticle.create!(title: 'First')
    article.update_attributes!(title: 'Second')
    expect(article.audits).to equal(article.history_tracks)
    expect(article.audits.map(&:action)).to eq(%w[create update])
    expect(article.reload.audits.map(&:version)).to eq([1, 2])
    article.audits.last.undo!
    expect(article.reload.title).to eq('First')
  end

  it 'retains create, update and destroy tracking defaults' do
    article = AssociationArticle.create!(title: 'First')
    article.update_attributes!(title: 'Second')
    article.destroy
    expect(article.audits.map(&:action)).to eq(%w[create update destroy])
  end

  it 'does not override an existing model method' do
    expect do
      AssociationArticle.track_history(history_method: :title)
    end.to raise_error(ArgumentError, /already defined/)
  end

  it 'reserves tracking methods and generated tracking fields on first configuration' do
    %i[undo track_create history_trackable_options track_history? version modifier modifier_id].each do |name|
      expect do
        AssociationReservedArticle.track_history(history_method: name)
      end.to raise_error(ArgumentError, /already defined/)
    end
  end

  it 'accepts string names and the original association name' do
    AssociationArticle.define_history_tracks_alias('audit_trail')
    AssociationArticle.define_history_tracks_alias(:history_tracks)
    article = AssociationArticle.create!(title: 'First')
    expect(article.audit_trail).to equal(article.history_tracks)
  end
end
