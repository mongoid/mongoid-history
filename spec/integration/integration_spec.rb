require 'spec_helper'

describe Mongoid::History do
  before :all do
    class Post
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field           :title
      field           :body
      field           :rating
      field           :views, type: Integer

      embeds_many     :comments, store_as: :coms
      embeds_one      :section, store_as: :sec
      embeds_many     :tags, :cascade_callbacks => true

      accepts_nested_attributes_for :tags, :allow_destroy => true

      track_history   :on => [:title, :body], :track_destroy => true
    end

    class Comment
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field             :t, as: :title
      field             :body
      embedded_in       :commentable, polymorphic: true
      track_history     :on => [:title, :body], :scope => :post, :track_create => true, :track_destroy => true
    end

    class Section
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field             :t, as: :title
      embedded_in       :post
      track_history     :on => [:title], :scope => :post, :track_create => true, :track_destroy => true
    end

    class User
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field             :n, as: :name
      field             :em, as: :email
      field             :phone
      field             :address
      field             :city
      field             :country
      field             :aliases, :type => Array
      track_history     :except => [:email, :updated_at]
    end

    class Tag
      include Mongoid::Document
      # include Mongoid::Timestamps  (see: https://github.com/mongoid/mongoid/issues/3078)
      include Mongoid::History::Trackable

      belongs_to :updated_by, :class_name => "User"

      field             :title
      track_history     :on => [:title], :scope => :post, :track_create => true, :track_destroy => true, :modifier_field => :updated_by
    end

    class Foo < Comment
    end

    @persisted_history_options = Mongoid::History.trackable_class_options
  end

  before(:each){ Mongoid::History.trackable_class_options = @persisted_history_options }
  let(:user){ User.create(name: "Aaron", email: "aaron@randomemail.com", aliases: ['bob'], country: 'Canada', city: 'Toronto', address: '21 Jump Street') }
  let(:another_user){ User.create(:name => "Another Guy", :email => "anotherguy@randomemail.com") }
  let(:post){ Post.create(:title => "Test", :body => "Post", :modifier => user, :views => 100) }
  let(:comment){ post.comments.create(:title => "test", :body => "comment", :modifier => user) }
  let(:tag){ Tag.create(:title => "test") }

  describe "track" do
    describe "on creation" do
      it "should have one history track in comment" do
        comment.history_tracks.count.should == 1
      end

      it "should assign title and body on modified" do
        comment.history_tracks.first.modified.should == {'t' => "test", 'body' =>  "comment"}
      end

      it "should not assign title and body on original" do
        comment.history_tracks.first.original.should == {}
      end

      it "should assign modifier" do
        comment.history_tracks.first.modifier.should == user
      end

      it "should assign version" do
        comment.history_tracks.first.version.should == 1
      end

      it "should assign scope" do
        comment.history_tracks.first.scope.should == "post"
      end

      it "should assign method" do
        comment.history_tracks.first.action.should == "create"
      end

      it "should assign association_chain" do
        expected = [
          {'id' => post.id, 'name' => "Post"},
          {'id' => comment.id, 'name' => "coms"}
        ]
        comment.history_tracks.first.association_chain.should == expected
      end
    end

    describe "on destruction" do
      it "should have two history track records in post" do
        lambda {
          post.destroy
        }.should change(Tracker, :count).by(1)
      end

      it "should assign destroy on track record" do
        post.destroy
        post.history_tracks.last.action.should == "destroy"
      end

      it "should return affected attributes from track record" do
        post.destroy
        post.history_tracks.last.affected["title"].should == "Test"
      end
    end

    describe "on update non-embedded" do
      it "should create a history track if changed attributes match tracked attributes" do
        lambda {
          post.update_attributes(:title => "Another Test")
        }.should change(Tracker, :count).by(1)
      end

      it "should not create a history track if changed attributes do not match tracked attributes" do
        lambda {
          post.update_attributes(:rating => "untracked")
        }.should change(Tracker, :count).by(0)
      end

      it "should assign modified fields" do
        post.update_attributes(:title => "Another Test")
        post.history_tracks.last.modified.should == {
          "title" => "Another Test"
        }
      end

      it "should assign method field" do
        post.update_attributes(:title => "Another Test")
        post.history_tracks.last.action.should == "update"
      end

      it "should assign original fields" do
        post.update_attributes(:title => "Another Test")
        post.history_tracks.last.original.should == {
          "title" => "Test"
        }
      end

      it "should assign modifier" do
        post.update_attributes(:title => "Another Test")
        post.history_tracks.first.modifier.should == user
      end

      it "should assign version on history tracks" do
        post.update_attributes(:title => "Another Test")
        post.history_tracks.first.version.should == 1
      end

      it "should assign version on post" do
        post.update_attributes(:title => "Another Test")
        post.version.should == 1
      end

      it "should assign scope" do
        post.update_attributes(:title => "Another Test")
        post.history_tracks.first.scope.should == "post"
      end

      it "should assign association_chain" do
        post.update_attributes(:title => "Another Test")
        post.history_tracks.last.association_chain.should == [{'id' => post.id, 'name' => "Post"}]
      end

      it "should exclude defined options" do
        name = user.name
        user.update_attributes(:name => "Aaron2", :email => "aaronsnewemail@randomemail.com")
        user.history_tracks.first.original.keys.should == [ "n" ]
        user.history_tracks.first.original["n"].should == name
        user.history_tracks.first.modified.keys.should == [ "n" ]
        user.history_tracks.first.modified["n"].should == user.name
      end

      it "should undo field changes" do
        name = user.name
        user.update_attributes(:name => "Aaron2", :email => "aaronsnewemail@randomemail.com")
        user.history_tracks.first.undo! nil
        user.reload.name.should == name
      end

      it "should undo non-existing field changes" do
        post = Post.create(:modifier => user, :views => 100)
        post.reload.title.should == nil
        post.update_attributes(:title => "Aaron2")
        post.reload.title.should == "Aaron2"
        post.history_tracks.first.undo! nil
        post.reload.title.should == nil
      end

      it "should track array changes" do
        aliases = user.aliases
        user.update_attributes(:aliases => [ 'bob', 'joe' ])
        user.history_tracks.first.original["aliases"].should == aliases
        user.history_tracks.first.modified["aliases"].should == user.aliases
      end

      it "should undo array changes" do
        aliases = user.aliases
        user.update_attributes(:aliases => [ 'bob', 'joe' ])
        user.history_tracks.first.undo! nil
        user.reload.aliases.should == aliases
      end
    end

    describe "#tracked_changes" do
      context "create action" do
        subject{ tag.history_tracks.first.tracked_changes }
        it "consider all fields values as :to" do
          subject[:title].should == {to: "test"}.with_indifferent_access
        end
      end
      context "destroy action" do
        subject{ tag.destroy; tag.history_tracks.last.tracked_changes }
        it "consider all fields values as :from" do
          subject[:title].should == {from: "test"}.with_indifferent_access
        end
      end
      context "update action" do
        subject{ user.history_tracks.first.tracked_changes }
        before do
          user.update_attributes(name: "Aaron2", email: nil, country: '',  city: nil, phone: '867-5309', aliases: ['','bill','james'])
        end
        it{ should be_a HashWithIndifferentAccess }
        it "should track changed field" do
          subject[:n].should == {from: "Aaron", to:"Aaron2"}.with_indifferent_access
        end
        it "should track added field" do
          subject[:phone].should == {to: "867-5309"}.with_indifferent_access
        end
        it "should track removed field" do
          subject[:city].should == {from: "Toronto"}.with_indifferent_access
        end
        it "should not consider blank as removed" do
          subject[:country].should == {from: "Canada", to: ''}.with_indifferent_access
        end
        it "should track changed array field" do
          subject[:aliases].should == {from: ["bob"], to: ["", "bill", "james"]}.with_indifferent_access
        end
        it "should not track unmodified field" do
          subject[:address].should be_nil
        end
        it "should not track untracked fields" do
          subject[:email].should be_nil
        end
      end
    end

    describe "#tracked_edits" do
      context "create action" do
        subject{ tag.history_tracks.first.tracked_edits }
        it "consider all edits as ;add" do
          subject[:add].should == {title: "test"}.with_indifferent_access
        end
      end
      context "destroy action" do
        subject{ tag.destroy; tag.history_tracks.last.tracked_edits }
        it "consider all edits as ;remove" do
          subject[:remove].should == {title: "test"}.with_indifferent_access
        end
      end
      context "update action" do
        subject{ user.history_tracks.first.tracked_edits }
        before do
          user.update_attributes(name: "Aaron2", email: nil, country: '', city: nil, phone: '867-5309', aliases: ['','bill','james'])
        end
        it{ should be_a HashWithIndifferentAccess }
        it "should track changed field" do
          subject[:modify].should == {n: {from: "Aaron", to:"Aaron2"}}.with_indifferent_access
        end
        it "should track added field" do
          subject[:add].should == {phone: "867-5309"}.with_indifferent_access
        end
        it "should track removed field and consider blank as removed" do
          subject[:remove].should == {city: "Toronto", country: "Canada"}.with_indifferent_access
        end
        it "should track changed array field" do
          subject[:array].should == {aliases: {remove: ["bob"], add: ["", "bill", "james"]}}.with_indifferent_access
        end
        it "should not track unmodified field" do
          %w(add modify remove array).each do |edit|
            subject[edit][:address].should be_nil
          end
        end
        it "should not track untracked fields" do
          %w(add modify remove array).each do |edit|
            subject[edit][:email].should be_nil
          end
        end
      end
      context "with empty values" do
        subject{ Tracker.new }
        it "should skip empty values" do
          subject.stub(:tracked_changes){ {name:{to:'',from:[]}, city:{to:'Toronto',from:''}} }
          subject.tracked_edits.should == {add: {city: "Toronto"}}.with_indifferent_access
        end
      end
    end

    describe "on update non-embedded twice" do
      it "should assign version on post" do
        post.update_attributes(:title => "Test2")
        post.update_attributes(:title => "Test3")
        post.version.should == 2
      end

      it "should create a history track if changed attributes match tracked attributes" do
        lambda {
          post.update_attributes(:title => "Test2")
          post.update_attributes(:title => "Test3")
        }.should change(Tracker, :count).by(2)
      end

      it "should create a history track of version 2" do
        post.update_attributes(:title => "Test2")
        post.update_attributes(:title => "Test3")
        post.history_tracks.where(:version => 2).first.should_not be_nil
      end

      it "should assign modified fields" do
        post.update_attributes(:title => "Test2")
        post.update_attributes(:title => "Test3")
        post.history_tracks.where(:version => 2).first.modified.should == {
          "title" => "Test3"
        }
      end

      it "should assign original fields" do
        post.update_attributes(:title => "Test2")
        post.update_attributes(:title => "Test3")
        post.history_tracks.where(:version => 2).first.original.should == {
          "title" => "Test2"
        }
      end


      it "should assign modifier" do
        post.update_attributes(:title => "Another Test", :modifier => another_user)
        post.history_tracks.last.modifier.should == another_user
      end
    end

    describe "on update embedded 1..N (embeds_many)" do
      it "should assign version on comment" do
        comment.update_attributes(:title => "Test2")
        comment.version.should == 2 # first track generated on creation
      end

      it "should create a history track of version 2" do
        comment.update_attributes(:title => "Test2")
        comment.history_tracks.where(:version => 2).first.should_not be_nil
      end

      it "should assign modified fields" do
        comment.update_attributes(:t => "Test2")
        comment.history_tracks.where(:version => 2).first.modified.should == {
          "t" => "Test2"
        }
      end

      it "should assign original fields" do
        comment.update_attributes(:title => "Test2")
        comment.history_tracks.where(:version => 2).first.original.should == {
          "t" => "test"
        }
      end

      it "should be possible to undo from parent" do
        comment.update_attributes(:title => "Test 2")
        user
        post.history_tracks.last.undo!(user)
        comment.reload
        comment.title.should == "test"
      end

      it "should assign modifier" do
        post.update_attributes(:title => "Another Test", :modifier => another_user)
        post.history_tracks.last.modifier.should == another_user
      end
    end

    describe "on update embedded 1..1 (embeds_one)" do
      let(:section){ Section.new(:title => 'Technology') }

      before(:each) do
        post.section = section
        post.save!
        post.reload
        section = post.section
      end

      it "should assign version on create section" do
        section.version.should == 1
      end

      it "should assign version on section" do
        section.update_attributes(:title => 'Technology 2')
        section.version.should == 2 # first track generated on creation
      end

      it "should create a history track of version 2" do
        section.update_attributes(:title => 'Technology 2')
        section.history_tracks.where(:version => 2).first.should_not be_nil
      end

      it "should assign modified fields" do
        section.update_attributes(:title => 'Technology 2')
        section.history_tracks.where(:version => 2).first.modified.should == {
          "t" => "Technology 2"
        }
      end

      it "should assign original fields" do
        section.update_attributes(:title => 'Technology 2')
        section.history_tracks.where(:version => 2).first.original.should == {
          "t" => "Technology"
        }
      end

      it "should be possible to undo from parent" do
        section.update_attributes(:title => 'Technology 2')
        post.history_tracks.last.undo!(user)
        section.reload
        section.title.should == "Technology"
      end

      it "should assign modifier" do
        section.update_attributes(:title => "Business", :modifier => another_user)
        post.history_tracks.last.modifier.should == another_user
      end
    end

    describe "on destroy embedded" do
      it "should be possible to re-create destroyed embedded" do
        comment.destroy
        comment.history_tracks.last.undo!(user)
        post.reload
        post.comments.first.title.should == "test"
      end

      it "should be possible to re-create destroyed embedded from parent" do
        comment.destroy
        post.history_tracks.last.undo!(user)
        post.reload
        post.comments.first.title.should == "test"
      end

      it "should be possible to destroy after re-create embedded from parent" do
        comment.destroy
        post.history_tracks.last.undo!(user)
        post.history_tracks.last.undo!(user)
        post.reload
        post.comments.count.should == 0
      end

      it "should be possible to create with redo after undo create embedded from parent" do
        comment # initialize
        post.comments.create!(:title => "The second one")
        track = post.history_tracks.last
        track.undo!(user)
        track.redo!(user)
        post.reload
        post.comments.count.should == 2
      end
    end

    describe "embedded with cascading callbacks" do

      let(:tag_foo){ post.tags.create(:title => "foo", :updated_by => user) }
      let(:tag_bar){ post.tags.create(:title => "bar") }

      # it "should have cascaded the creation callbacks and set timestamps" do
      #   tag_foo; tag_bar # initialize
      #   tag_foo.created_at.should_not be_nil
      #   tag_foo.updated_at.should_not be_nil
      # end

      it "should allow an update through the parent model" do
        update_hash = { "post" => { "tags_attributes" => { "1234" => { "id" => tag_bar.id, "title" => "baz" } } } }
        post.update_attributes(update_hash["post"])
        post.tags.last.title.should == "baz"
      end

      it "should be possible to destroy through parent model using canoncial _destroy macro" do
        tag_foo; tag_bar # initialize
        post.tags.count.should == 2
        update_hash = { "post" => { "tags_attributes" => { "1234" => { "id" => tag_bar.id, "title" => "baz", "_destroy" => "true"} } } }
        post.update_attributes(update_hash["post"])
        post.tags.count.should == 1
        post.history_tracks.to_a.last.action.should == "destroy"
      end

      it "should write relationship name for association_chain hiearchy instead of class name when using _destroy macro" do
        update_hash = {"tags_attributes" => { "1234" => { "id" => tag_foo.id, "_destroy" => "1"} } }
        post.update_attributes(update_hash)

        # historically this would have evaluated to 'Tags' and an error would be thrown
        # on any call that walked up the association_chain, e.g. 'trackable'
        tag_foo.history_tracks.last.association_chain.last["name"].should == "tags"
        lambda{ tag_foo.history_tracks.last.trackable }.should_not raise_error
      end
    end

    describe "non-embedded" do
      it "should undo changes" do
        post.update_attributes(:title => "Test2")
        post.history_tracks.where(:version => 1).last.undo!(user)
        post.reload
        post.title.should == "Test"
      end

      it "should undo destruction" do
        post.destroy
        post.history_tracks.where(:version => 1).last.undo!(user)
        Post.find(post.id).title.should == "Test"
      end

      it "should create a new history track after undo" do
        comment # initialize
        post.update_attributes(:title => "Test2")
        post.history_tracks.last.undo!(user)
        post.reload
        post.history_tracks.count.should == 3
      end

      it "should assign user as the modifier of the newly created history track" do
        post.update_attributes(:title => "Test2")
        post.history_tracks.where(:version => 1).last.undo!(user)
        post.reload
        post.history_tracks.where(:version => 2).last.modifier.should == user
      end

      it "should stay the same after undo and redo" do
        post.update_attributes(:title => "Test2")
        track = post.history_tracks.last
        track.undo!(user)
        track.redo!(user)
        post2 = Post.where(:_id => post.id).first

        post.title.should == post2.title
      end

      it "should be destroyed after undo and redo" do
        post.destroy
        track = post.history_tracks.where(:version => 1).last
        track.undo!(user)
        track.redo!(user)
        Post.where(:_id => post.id).first.should == nil
      end
    end

    describe "embedded" do
      it "should undo changes" do
        comment.update_attributes(:title => "Test2")
        comment.history_tracks.where(:version => 2).first.undo!(user)
        comment.reload
        comment.title.should == "test"
      end

      it "should create a new history track after undo" do
        comment.update_attributes(:title => "Test2")
        comment.history_tracks.where(:version => 2).first.undo!(user)
        comment.reload
        comment.history_tracks.count.should == 3
      end

      it "should assign user as the modifier of the newly created history track" do
        comment.update_attributes(:title => "Test2")
        comment.history_tracks.where(:version => 2).first.undo!(user)
        comment.reload
        comment.history_tracks.where(:version => 3).first.modifier.should == user
      end

      it "should stay the same after undo and redo" do
        comment.update_attributes(:title => "Test2")
        track = comment.history_tracks.where(:version => 2).first
        track.undo!(user)
        track.redo!(user)
        comment.reload
        comment.title.should == "Test2"
      end
    end

    describe "trackables" do
      before :each do
        comment.update_attributes(:title => "Test2") # version == 2
        comment.update_attributes(:title => "Test3") # version == 3
        comment.update_attributes(:title => "Test4") # version == 4
      end

      describe "undo" do
        it "should recognize :from, :to options" do
          comment.undo! user, :from => 4, :to => 2
          comment.title.should == "test"
        end

        it "should recognize parameter as version number" do
          comment.undo! user, 3
          comment.title.should == "Test2"
        end

        it "should undo last version when no parameter is specified" do
          comment.undo! user
          comment.title.should == "Test3"
        end

        it "should recognize :last options" do
          comment.undo! user, :last => 2
          comment.title.should == "Test2"
        end

      end

      describe "redo" do
        before :each do
          comment.update_attributes(:title => "Test5")
        end

        it "should recognize :from, :to options" do
          comment.redo! user,  :from => 2, :to => 4
          comment.title.should == "Test4"
        end

        it "should recognize parameter as version number" do
          comment.redo! user, 2
          comment.title.should == "Test2"
        end

        it "should redo last version when no parameter is specified" do
          comment.redo! user
          comment.title.should == "Test5"
        end

        it "should recognize :last options" do
          comment.redo! user, :last => 1
          comment.title.should == "Test5"
        end

      end
    end

    describe "localized fields" do
      before :each do
        class Sausage
          include Mongoid::Document
          include Mongoid::History::Trackable

          field           :flavour, localize: true
          track_history   :on => [:flavour], :track_destroy => true
        end
      end
      it "should correctly undo and redo" do
        if Sausage.respond_to?(:localized_fields)
          sausage = Sausage.create(flavour_translations: { 'en' => "Apple", 'nl' => 'Appel' } )
          sausage.update_attributes(:flavour => "Guinness")

          track = sausage.history_tracks.last

          track.undo! user
          sausage.reload.flavour.should == "Apple"

          track.redo! user
          sausage.reload.flavour.should == "Guinness"

          sausage.destroy
          sausage.history_tracks.last.action.should == "destroy"
          sausage.history_tracks.last.undo! user
          sausage.reload.flavour.should == "Guinness"
        end
      end
    end

    describe "embedded with a polymorphic trackable" do
      let(:foo){ Foo.new(:title => 'a title', :body => 'a body') }
      before :each do
        post.comments << foo
        post.save
      end
      it "should assign interface name in association chain" do
        foo.update_attribute(:body, 'a changed body')
        expected_root = {"name" => "Post", "id" => post.id}
        expected_node = {"name" => "coms", "id" => foo.id}
        foo.history_tracks.first.association_chain.should == [expected_root, expected_node]
      end
    end

    describe "#trackable_parent_class" do
      context "a non-embedded model" do
        it "should return the trackable parent class" do
          tag.history_tracks.first.trackable_parent_class.should == Tag
        end
        it "should return the parent class even if the trackable is deleted" do
          tracker = tag.history_tracks.first
          tag.destroy
          tracker.trackable_parent_class.should == Tag
        end
      end
      context "an embedded model" do
        it "should return the trackable parent class" do
          comment.update_attributes(title: "Foo")
          comment.history_tracks.first.trackable_parent_class.should == Post
        end
        it "should return the parent class even if the trackable is deleted" do
          tracker = comment.history_tracks.first
          comment.destroy
          tracker.trackable_parent_class.should == Post
        end
      end
    end
  end
end
