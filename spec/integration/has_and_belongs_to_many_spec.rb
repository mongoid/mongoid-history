require 'spec_helper'

describe Mongoid::History do
  before :all do
    class Post
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :title
      field :body
      has_and_belongs_to_many :tags, before_add: :track_has_and_belongs_to_many, before_remove: :track_has_and_belongs_to_many
      track_history on: %i[all], track_create: false, track_update: false
    end

    class Tag
      include Mongoid::Document

      field :title
      has_and_belongs_to_many :posts
    end
  end

  describe 'track' do
    let(:tag) { Tag.create! }

    describe 'on creation' do
      let(:post) { Post.create!(tags: [tag]) }

      it 'should create track' do
        expect(post.history_tracks.count).to eq(1)
      end

      it 'should assign tag_ids on modified' do
        expect(post.history_tracks.first.modified).to include('tag_ids' => [tag.id])
      end

      it 'should assign empty tag_ids on original' do
        expect(post.history_tracks.first.original).to include('tag_ids' => [])
      end
    end

    describe 'on add' do
      let(:post) { Post.create!(tags: [tag]) }
      let(:tag2) { Tag.create! }
      before { post.tags << tag2 }

      # this just verifies that post is updated above
      it 'should update tags' do
        expect(post.reload.tags).to eq([tag, tag2])
      end

      it 'should create track' do
        expect(post.history_tracks.count).to eq(2)
      end

      it 'should assign tag_ids on modified' do
        expect(post.history_tracks.last.modified).to include('tag_ids' => [tag.id, tag2.id])
      end

      it 'should assign empty tag_ids on original' do
        expect(post.history_tracks.last.original).to include('tag_ids' => [tag.id])
      end
    end

    describe 'on remove' do
      let(:post) { Post.create!(tags: [tag]) }
      before { post.tags = [] }

      # this just verifies that post is updated above
      it 'should update tags' do
        expect(post.reload.tags).to eq([])
      end

      it 'should create two tracks' do
        expect(post.history_tracks.count).to eq(2)
      end

      it 'should assign empty tag_ids on modified' do
        expect(post.history_tracks.last.modified).to include('tag_ids' => [])
      end

      it 'should assign tag_ids on original' do
        expect(post.history_tracks.last.original).to include('tag_ids' => [tag.id])
      end
    end

    describe 'on reassign' do
      let(:post) { Post.create!(tags: [tag]) }
      let(:tag2) { Tag.create! }
      before { post.tags = [tag2] }

      # this just verifies that post is updated above
      it 'should update tags' do
        expect(post.reload.tags).to eq([tag2])
      end

      it 'should create three tracks' do
        # 1. tags: [tag]
        # 2. tags: []
        # 3. tags: [tag2]
        expect(post.history_tracks.count).to eq(3)
      end

      it 'should assign tag_ids on modified' do
        expect(post.history_tracks.last.modified).to include('tag_ids' => [tag2.id])
      end

      it 'should assign empty tag_ids on original' do
        expect(post.history_tracks.last.original).to include('tag_ids' => [])
      end
    end
  end

  after :all do
    Object.send(:remove_const, :Post)
    Object.send(:remove_const, :Tag)
  end
end
