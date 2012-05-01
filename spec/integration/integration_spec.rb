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
      embeds_one      :section
      embeds_many     :tags, :cascade_callbacks => true

      accepts_nested_attributes_for :tags, :allow_destroy => true

      track_history   :on => [:title, :body], :track_destroy => true
    end

    class Comment
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field             :title
      field             :body
      embedded_in       :post
      track_history     :on => [:title, :body], :scope => :post, :track_create => true, :track_destroy => true
    end

    class Section
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field             :title
      embedded_in       :post
      track_history     :on => [:title], :scope => :post, :track_create => true, :track_destroy => true
    end

    class User
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field             :email
      field             :name
      track_history     :except => [:email]
    end

    class Tag
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field             :title
      track_history     :on => [:title], :scope => :post, :track_create => true, :track_destroy => true
    end
  end

  before :each do
    @user = User.create(:name => "Aaron", :email => "aaron@randomemail.com")
    @another_user = User.create(:name => "Another Guy", :email => "anotherguy@randomemail.com")
    @post = Post.create(:title => "Test", :body => "Post", :modifier => @user, :views => 100)
    @comment = @post.comments.create(:title => "test", :body => "comment", :modifier => @user)
  end

  describe "track" do
    describe "on creation" do
      it "should have one history track in comment" do
        @comment.history_tracks.count.should == 1
      end

      it "should assign title and body on modified" do
        @comment.history_tracks.first.modified.should == {'title' => "test", 'body' =>  "comment"}
      end

      it "should not assign title and body on original" do
        @comment.history_tracks.first.original.should == {}
      end

      it "should assign modifier" do
        @comment.history_tracks.first.modifier.should == @user
      end

      it "should assign version" do
        @comment.history_tracks.first.version.should == 1
      end

      it "should assign scope" do
        @comment.history_tracks.first.scope.should == "post"
      end

      it "should assign method" do
        @comment.history_tracks.first.action.should == "create"
      end

      it "should assign association_chain" do
        expected = [
          {'id' => @post.id, 'name' => "Post"},
          {'id' => @comment.id, 'name' => "comments"}
        ]
        @comment.history_tracks.first.association_chain.should == expected
      end
    end

    describe "on destruction" do
      it "should have two history track records in post" do
        lambda {
          @post.destroy
        }.should change(HistoryTracker, :count).by(1)
      end

      it "should assign destroy on track record" do
        @post.destroy
        @post.history_tracks.last.action.should == "destroy"
      end

      it "should return affected attributes from track record" do
        @post.destroy
        @post.history_tracks.last.affected["title"].should == "Test"
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
        @post.history_tracks.last.modified.should == {
          "title" => "Another Test"
        }
      end

      it "should assign method field" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.last.action.should == "update"
      end

      it "should assign original fields" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.last.original.should == {
          "title" => "Test"
        }
      end

      it "should assign modifier" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.first.modifier.should == @user
      end

      it "should assign version on history tracks" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.first.version.should == 1
      end

      it "should assign version on post" do
        @post.update_attributes(:title => "Another Test")
        @post.version.should == 1
      end

      it "should assign scope" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.first.scope.should == "post"
      end

      it "should assign association_chain" do
        @post.update_attributes(:title => "Another Test")
        @post.history_tracks.last.association_chain.should == [{'id' => @post.id, 'name' => "Post"}]
      end

      it "should exclude defined options" do
        @user.update_attributes(:name => "Aaron2", :email => "aaronsnewemail@randomemail.com")
        @user.history_tracks.first.modified.should == {
          "name" => "Aaron2"
        }
      end
    end

    describe "on update non-embedded twice" do
      it "should assign version on post" do
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
          "title" => "Test3"
        }
      end

      it "should assign original fields" do
        @post.update_attributes(:title => "Test2")
        @post.update_attributes(:title => "Test3")
        @post.history_tracks.where(:version => 2).first.original.should == {
          "title" => "Test2"
        }
      end


      it "should assign modifier" do
        @post.update_attributes(:title => "Another Test", :modifier => @another_user)
        @post.history_tracks.last.modifier.should == @another_user
      end
    end

    describe "on update embedded 1..N (embeds_many)" do
      it "should assign version on comment" do
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
          "title" => "Test2"
        }
      end

      it "should assign original fields" do
        @comment.update_attributes(:title => "Test2")
        @comment.history_tracks.where(:version => 2).first.original.should == {
          "title" => "test"
        }
      end

      it "should be possible to undo from parent" do
        @comment.update_attributes(:title => "Test 2")
        @post.history_tracks.last.undo!(@user)
        @comment.reload
        @comment.title.should == "test"
      end

      it "should assign modifier" do
        @post.update_attributes(:title => "Another Test", :modifier => @another_user)
        @post.history_tracks.last.modifier.should == @another_user
      end
    end

    describe "on update embedded 1..1 (embeds_one)" do
      before(:each) do
        @section = Section.new(:title => 'Technology')
        @post.section = @section
        @post.save!
        @post.reload
        @section = @post.section
      end

      it "should assign version on create section" do
        @section.version.should == 1
      end

      it "should assign version on section" do
        @section.update_attributes(:title => 'Technology 2')
        @section.version.should == 2 # first track generated on creation
      end

      it "should create a history track of version 2" do
        @section.update_attributes(:title => 'Technology 2')
        @section.history_tracks.where(:version => 2).first.should_not be_nil
      end

      it "should assign modified fields" do
        @section.update_attributes(:title => 'Technology 2')
        @section.history_tracks.where(:version => 2).first.modified.should == {
          "title" => "Technology 2"
        }
      end

      it "should assign original fields" do
        @section.update_attributes(:title => 'Technology 2')
        @section.history_tracks.where(:version => 2).first.original.should == {
          "title" => "Technology"
        }
      end

      it "should be possible to undo from parent" do
        @section.update_attributes(:title => 'Technology 2')
        @post.history_tracks.last.undo!(@user)
        @section.reload
        @section.title.should == "Technology"
      end

      it "should assign modifier" do
        @section.update_attributes(:title => "Business", :modifier => @another_user)
        @post.history_tracks.last.modifier.should == @another_user
      end
    end

    describe "on destroy embedded" do
      it "should be possible to re-create destroyed embedded" do
        @comment.destroy
        @comment.history_tracks.last.undo!(@user)
        @post.reload
        @post.comments.first.title.should == "test"
      end

      it "should be possible to re-create destroyed embedded from parent" do
        @comment.destroy
        @post.history_tracks.last.undo!(@user)
        @post.reload
        @post.comments.first.title.should == "test"
      end

      it "should be possible to destroy after re-create embedded from parent" do
        @comment.destroy
        @post.history_tracks.last.undo!(@user)
        @post.history_tracks.last.undo!(@user)
        @post.reload
        @post.comments.count.should == 0
      end

      it "should be possible to create with redo after undo create embedded from parent" do
        @post.comments.create!(:title => "The second one")
        @track = @post.history_tracks.last
        @track.undo!(@user)
        @track.redo!(@user)
        @post.reload
        @post.comments.count.should == 2
      end
    end

    describe "embedded with cascading callbacks" do
      before(:each) do
        @tag_foo = @post.tags.create(:title => "foo", :modifier => @user)
        @tag_bar = @post.tags.create(:title => "bar", :modifier => @user)
      end

      it "should have cascaded the creation callbacks and set timestamps" do
        @tag_foo.created_at.should_not be_nil
        @tag_foo.updated_at.should_not be_nil
      end

      it "should allow an update through the parent model" do
        update_hash = { "post" => { "tags_attributes" => { "1234" => { "id" => @tag_bar.id, "title" => "baz" } } } }
        @post.update_attributes(update_hash["post"])
        @post.tags.last.title.should == "baz"
      end

      it "should be possible to destroy through parent model using canoncial _destroy macro" do
        @post.tags.count.should == 2
        update_hash = { "post" => { "tags_attributes" => { "1234" => { "id" => @tag_bar.id, "title" => "baz", "_destroy" => "true"} } } }
        @post.update_attributes(update_hash["post"])
        @post.tags.count.should == 1
        @post.history_tracks.last.action.should == "destroy"
      end

      it "should write relationship name for association_chain hiearchy instead of class name when using _destroy macro" do
        update_hash = {"tags_attributes" => { "1234" => { "id" => @tag_foo.id, "_destroy" => "1"} } }
        @post.update_attributes(update_hash)

        # historically this would have evaluated to 'Tags' and an error would be thrown
        # on any call that walked up the association_chain, e.g. 'trackable'
        @tag_foo.history_tracks.last.association_chain.last["name"].should == "tags"
        lambda{ @tag_foo.history_tracks.last.trackable }.should_not raise_error
      end
    end

    describe "non-embedded" do
      it "should undo changes" do
        @post.update_attributes(:title => "Test2")
        @post.history_tracks.where(:version => 1).last.undo!(@user)
        @post.reload
        @post.title.should == "Test"
      end

      it "should undo destruction" do
        @post.destroy
        @post.history_tracks.where(:version => 1).last.undo!(@user)
        Post.find(@post.id).title.should == "Test"
      end

      it "should create a new history track after undo" do
        @post.update_attributes(:title => "Test2")
        @post.history_tracks.last.undo!(@user)
        @post.reload
        @post.history_tracks.count.should == 3
      end

      it "should assign @user as the modifier of the newly created history track" do
        @post.update_attributes(:title => "Test2")
        @post.history_tracks.where(:version => 1).last.undo!(@user)
        @post.reload
        @post.history_tracks.where(:version => 2).last.modifier.should == @user
      end

      it "should stay the same after undo and redo" do
        @post.update_attributes(:title => "Test2")
        @track = @post.history_tracks.last
        @track.undo!(@user)
        @track.redo!(@user)
        @post2 = Post.where(:_id => @post.id).first

        @post.title.should == @post2.title
      end

      it "should be destroyed after undo and redo" do
        @post.destroy
        @track = @post.history_tracks.where(:version => 1).last
        @track.undo!(@user)
        @track.redo!(@user)
        Post.where(:_id => @post.id).first.should == nil
      end
    end

    describe "embedded" do
      it "should undo changes" do
        @comment.update_attributes(:title => "Test2")
        @comment.history_tracks.where(:version => 2).first.undo!(@user)
        # reloading an embedded document === KAMIKAZE
        # at least for the current release of mongoid...
        @post.reload
        @comment = @post.comments.first
        @comment.title.should == "test"
      end

      it "should create a new history track after undo" do
        @comment.update_attributes(:title => "Test2")
        @comment.history_tracks.where(:version => 2).first.undo!(@user)
        @post.reload
        @comment = @post.comments.first
        @comment.history_tracks.count.should == 3
      end

      it "should assign @user as the modifier of the newly created history track" do
        @comment.update_attributes(:title => "Test2")
        @comment.history_tracks.where(:version => 2).first.undo!(@user)
        @post.reload
        @comment = @post.comments.first
        @comment.history_tracks.where(:version => 3).first.modifier.should == @user
      end

      it "should stay the same after undo and redo" do
        @comment.update_attributes(:title => "Test2")
        @track = @comment.history_tracks.where(:version => 2).first
        @track.undo!(@user)
        @track.redo!(@user)
        @post2 = Post.where(:_id => @post.id).first
        @comment2 = @post2.comments.first

        @comment.title.should == @comment2.title
      end
    end

    describe "trackables" do
      before :each do
        @comment.update_attributes(:title => "Test2") # version == 2
        @comment.update_attributes(:title => "Test3") # version == 3
        @comment.update_attributes(:title => "Test4") # version == 4
      end

      describe "undo" do
        it "should recognize :from, :to options" do
          @comment.undo! @user, :from => 4, :to => 2
          @comment.title.should == "test"
        end

        it "should recognize parameter as version number" do
          @comment.undo! @user, 3
          @comment.title.should == "Test2"
        end

        it "should undo last version when no parameter is specified" do
          @comment.undo! @user
          @comment.title.should == "Test3"
        end

        it "should recognize :last options" do
          @comment.undo! @user, :last => 2
          @comment.title.should == "Test2"
        end
      end

      describe "redo" do
        before :each do
          @comment.update_attributes(:title => "Test5")
        end

        it "should recognize :from, :to options" do
          @comment.redo! @user,  :from => 2, :to => 4
          @comment.title.should == "Test4"
        end

        it "should recognize parameter as version number" do
          @comment.redo! @user, 2
          @comment.title.should == "Test2"
        end

        it "should redo last version when no parameter is specified" do
          @comment.redo! @user
          @comment.title.should == "Test5"
        end

        it "should recognize :last options" do
          @comment.redo! @user, :last => 1
          @comment.title.should == "Test5"
        end

      end
    end
  end
end
