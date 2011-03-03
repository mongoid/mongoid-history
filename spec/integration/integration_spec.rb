require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongoid::History do
  before :all do
    class HistoryTracker
      include Mongoid::History::Tracker
    end

    class Post
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field           :title
      field           :body
      field           :rating
      embeds_many     :comments
      track_history   :on => [:title, :body]
    end

    class Comment
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field             :title
      field             :body
      embedded_in       :post, :inverse_of => :comments
      track_history     :on => [:title, :body], :scope => :post, :track_create => true
    end

    class User
      include Mongoid::Document
      include Mongoid::Timestamps

      field             :name
    end
  end
  
  before :each do
    @user = User.create(:name => "Aaron")
    @another_user = User.create(:name => "Another Guy")
    @post = Post.create(:title => "Test", :body => "Post", :modifier => @user)
    @comment = @post.comments.create(:title => "test", :body => "comment", :modifier => @user)
  end
  
  describe "track" do
    describe "on creation" do
      it "should have one history track in comment" do
        @comment.history_tracks.count.should == 1
      end
      
      it "should assign title and body" do
        @comment.history_tracks.first.modified.should == {'title' => [nil, "test"], 'body' => [nil, "comment"]}
      end
      
      it "should assign modifier" do
        @comment.history_tracks.first.modifier.should == @user
      end
      
      it "should assigin version" do
        @comment.history_tracks.first.version.should == 1
      end
      
      it "should assigin scope" do
        @comment.history_tracks.first.scope == "Post"
      end
      
      it "should assigin association_chain" do
        @comment.history_tracks.first.association_chain = [{:id => @post.id, :name => "Post"}, {:id => @comment.id, :name => "Comment"}]
      end
    end
    
    describe "on update non-embedded" do
      it "should create a history track if changed attributes match tracked attributes" do
        lambda {
          @post.update_attributes(:title => "Another Test")
        }.should change(HistoryTracker, :count).by(1)        
      end

      it "should not create a history track if changed attributes do not match tracked attributes" do
        lambda {
          @post.update_attributes(:rating => "untracked")
        }.should change(HistoryTracker, :count).by(0)
      end
      
      it "should assign modified fields" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.first.modified.should == {
          "title" => ["Test", "Another Test"]
        }
      end

      it "should assign modifier" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.first.modifier.should == @user
      end

      it "should assigin version on history tracks" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.first.version.should == 1
      end
      
      it "should assigin version on post" do
        @post.update_attributes(:title => "Another Test")
        @post.version.should == 1
      end

      it "should assigin scope" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.first.scope == "Post"
      end

      it "should assigin association_chain" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.first.association_chain = [{:id => @post.id, :name => "Post"}]
      end
    end
    
    describe "on update non-embedded twice" do
      it "should assigin version on post" do
        @post.update_attributes(:title => "Test2")
        @post.update_attributes(:title => "Test3")
        @post.version.should == 2
      end

      it "should create a history track if changed attributes match tracked attributes" do
        lambda {
          @post.update_attributes(:title => "Test2")
          @post.update_attributes(:title => "Test3")
        }.should change(HistoryTracker, :count).by(2)        
      end
      
      it "should create a history track of version 2" do
        @post.update_attributes(:title => "Test2")
        @post.update_attributes(:title => "Test3")
        @post.history_tracks.where(:version => 2).first.should_not be_nil
      end
      
      it "should assign modified fields" do
        @post.update_attributes(:title => "Test2")
        @post.update_attributes(:title => "Test3")
        @post.history_tracks.where(:version => 2).first.modified.should == {
          "title" => ["Test2", "Test3"]
        }
      end

      it "should assign modifier" do
        @post.update_attributes(:title => "Another Test", :modifier => @another_user)
        @post.history_tracks.first.modifier.should == @another_user
      end
    end
    
    describe "on update embedded" do
      it "should assigin version on comment" do
        @comment.update_attributes(:title => "Test2")
        @comment.version.should == 2 # first track generated on creation
      end

      it "should create a history track of version 2" do
        @comment.update_attributes(:title => "Test2")
        @comment.history_tracks.where(:version => 2).first.should_not be_nil
      end
      
      it "should assign modified fields" do
        @comment.update_attributes(:title => "Test2")
        @comment.history_tracks.where(:version => 2).first.modified.should == {
          "title" => ["test", "Test2"]
        }
      end

      it "should assign modifier" do
        @post.update_attributes(:title => "Another Test", :modifier => @another_user)
        @post.history_tracks.first.modifier.should == @another_user
      end
    end
    
    describe "undo on non-embedded" do
      it "should undo changes" do
        lambda {
          @post.update_attributes(:title => "Test2")
          @post.history_tracks.where(:version => 1).first.undo!
          @post.reload
        }.should_not change(@post, :title)
        
      end
    end
    
    describe "undo on embedded" do
      it "should undo changes" do
          @comment.update_attributes(:title => "Test2")
          @comment.history_tracks.where(:version => 2).first.undo!
          # reloading an embedded document === KAMIKAZE
          # at least for the current release of mongoid...
          @post.reload
          @comment = @post.comments.first
          @comment.title.should == "test"
      end
    end

  end
end
