require 'spec_helper'

describe Mongoid::History do
  before :all do
    class Post
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :title
      field :body
      has_and_belongs_to_many :tags
      track_history on: [:all], track_create: true, track_update: true
    end

    class Tag
      include Mongoid::Document

      field :title
      has_and_belongs_to_many :posts
    end

    @persisted_history_options = Mongoid::History.trackable_class_options
  end

  before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }
  let(:tag) { Tag.create! }

  describe 'track' do
    describe 'on creation' do
      let(:post) { Post.create!(tags: [tag]) }

      it 'should assign tag_ids on modified' do
        expect(post.history_tracks.first.modified).to include('tag_ids' => [tag.id])
      end

      it 'should not assign tag_ids on original' do
        expect(post.history_tracks.first.original).to eq({})
      end
    end

    describe 'on update' do
      let(:post) { Post.create! }
      before { post.tags = [tag] }

      # TODO: remove, this just tests mongoid
      it 'should update tags' do
        expect(post.reload.tags).to eq([tag])
      end

      it 'should create two tracks' do
        expect(post.history_tracks.count).to eq(2)
      end

      it 'should assign tag_ids on modified' do
        expect(post.history_tracks.last.modified).to include('tag_ids' => [tag.id])
      end

      it 'should not assign tag_ids on original' do
        expect(post.history_tracks.last.original).to eq({})
      end
    end
  end

  after :all do
    Object.send(:remove_const, :Post)
    Object.send(:remove_const, :Tag)
  end
end
