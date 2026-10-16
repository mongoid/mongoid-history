require 'spec_helper'

describe 'History reporting groups' do
  before do
    class GroupAudit
      include Mongoid::History::Tracker
    end

    class GroupArticle
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :title, type: String
      track_history modifier_field: nil, tracker_class_name: GroupAudit
    end
  end

  after do
    Object.send(:remove_const, :GroupArticle)
    Object.send(:remove_const, :GroupAudit)
  end

  it 'groups separate writes without coalescing their history or undo' do
    article = GroupArticle.create!(title: 'First')
    result = Mongoid::History.with_group('editing-session-1') do
      article.update_attributes!(title: 'Second')
      article.update_attributes!(title: 'Third')
      :result
    end
    expect(result).to eq(:result)
    expect(article.history_tracks.count).to eq(3)
    tracks = article.history_tracks.where(group_id: 'editing-session-1').to_a
    expect(tracks.map(&:version)).to eq([2, 3])
    tracks.last.undo!
    expect(article.reload.title).to eq('Second')
    expect(article.history_tracks.last.group_id).to be_nil
    tracks.last.redo!
    expect(article.reload.title).to eq('Third')
  end

  it 'can reuse a group across separate request blocks' do
    article = GroupArticle.create!(title: 'First')
    Mongoid::History.with_group('session') { article.update_attributes!(title: 'Second') }
    Mongoid::History.with_group('session') { article.update_attributes!(title: 'Third') }
    expect(GroupAudit.where(group_id: 'session').count).to eq(2)
    expect(Mongoid::History.group_id).to be_nil
  end

  it 'restores nested groups after exceptions' do
    Mongoid::History.with_group('outer') do
      expect do
        Mongoid::History.with_group('inner') { raise 'failure' }
      end.to raise_error('failure')
      expect(Mongoid::History.group_id).to eq('outer')
      Mongoid::History.with_group(nil) { expect(Mongoid::History.group_id).to be_nil }
      expect(Mongoid::History.group_id).to eq('outer')
    end
    expect(Mongoid::History.group_id).to be_nil
  end

  it 'does not share groups between threads' do
    Mongoid::History.with_group('main') do
      expect(Thread.new { Mongoid::History.group_id }.value).to be_nil
    end
  end

  it 'uses RequestStore when present' do
    stub_const('RequestStore', RequestStoreTemp)
    Mongoid::History.with_group('request') do
      expect(RequestStore.store[Mongoid::History::HISTORY_GROUP_KEY]).to eq('request')
    end
    expect(RequestStore.store[Mongoid::History::HISTORY_GROUP_KEY]).to be_nil
  end

  it 'retains successful writes when a later operation in the block fails' do
    article = GroupArticle.create!(title: 'First')
    expect do
      Mongoid::History.with_group('partial') do
        article.update_attributes!(title: 'Second')
        raise 'failure'
      end
    end.to raise_error('failure')
    expect(article.reload.title).to eq('Second')
    expect(article.history_tracks.where(group_id: 'partial').count).to eq(1)
    expect(Mongoid::History.group_id).to be_nil
  end
end
