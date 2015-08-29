require 'spec_helper'

describe Mongoid::History do
  before :all do
    class Post
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :title
      field :body
      field :rating
      field :views, type: Integer

      embeds_many :comments, store_as: :coms
      embeds_one :section, store_as: :sec
      embeds_many :tags, cascade_callbacks: true

      accepts_nested_attributes_for :tags, allow_destroy: true

      track_history on: [:title, :body], track_destroy: true
    end

    class Comment
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :t, as: :title
      field :body
      embedded_in :commentable, polymorphic: true
      track_history on: [:title, :body], scope: :post, track_create: true, track_destroy: true
    end

    class Section
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :t, as: :title
      embedded_in :post
      track_history on: [:title], scope: :post, track_create: true, track_destroy: true
    end

    class User
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :n, as: :name
      field :em, as: :email
      field :phone
      field :address
      field :city
      field :country
      field :aliases, type: Array
      track_history except: [:email, :updated_at]
    end

    class Tag
      include Mongoid::Document
      # include Mongoid::Timestamps  (see: https://github.com/mongoid/mongoid/issues/3078)
      include Mongoid::History::Trackable

      belongs_to :updated_by, class_name: 'User'

      field :title
      track_history on: [:title], scope: :post, track_create: true, track_destroy: true, modifier_field: :updated_by
    end

    class Foo < Comment
    end

    @persisted_history_options = Mongoid::History.trackable_class_options
  end

  before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }
  let(:user) { User.create(name: 'Aaron', email: 'aaron@randomemail.com', aliases: ['bob'], country: 'Canada', city: 'Toronto', address: '21 Jump Street') }
  let(:another_user) { User.create(name: 'Another Guy', email: 'anotherguy@randomemail.com') }
  let(:post) { Post.create(title: 'Test', body: 'Post', modifier: user, views: 100) }
  let(:comment) { post.comments.create(title: 'test', body: 'comment', modifier: user) }
  let(:tag) { Tag.create(title: 'test') }

  describe 'track' do
    describe 'on creation' do
      it 'should have one history track in comment' do
        expect(comment.history_tracks.count).to eq(1)
      end

      it 'should assign title and body on modified' do
        expect(comment.history_tracks.first.modified).to eq('t' => 'test', 'body' =>  'comment')
      end

      it 'should not assign title and body on original' do
        expect(comment.history_tracks.first.original).to eq({})
      end

      it 'should assign modifier' do
        expect(comment.history_tracks.first.modifier).to eq(user)
      end

      it 'should assign version' do
        expect(comment.history_tracks.first.version).to eq(1)
      end

      it 'should assign scope' do
        expect(comment.history_tracks.first.scope).to eq('post')
      end

      it 'should assign method' do
        expect(comment.history_tracks.first.action).to eq('create')
      end

      it 'should assign association_chain' do
        expected = [
          { 'id' => post.id, 'name' => 'Post' },
          { 'id' => comment.id, 'name' => 'coms' }
        ]
        expect(comment.history_tracks.first.association_chain).to eq(expected)
      end
    end

    describe 'on destruction' do
      it 'should have two history track records in post' do
        expect do
          post.destroy
        end.to change(Tracker, :count).by(1)
      end

      it 'should assign destroy on track record' do
        post.destroy
        expect(post.history_tracks.last.action).to eq('destroy')
      end

      it 'should return affected attributes from track record' do
        post.destroy
        expect(post.history_tracks.last.affected['title']).to eq('Test')
      end
    end

    describe 'on update non-embedded' do
      it 'should create a history track if changed attributes match tracked attributes' do
        expect do
          post.update_attributes(title: 'Another Test')
        end.to change(Tracker, :count).by(1)
      end

      it 'should not create a history track if changed attributes do not match tracked attributes' do
        expect do
          post.update_attributes(rating: 'untracked')
        end.to change(Tracker, :count).by(0)
      end

      it 'should assign modified fields' do
        post.update_attributes(title: 'Another Test')
        expect(post.history_tracks.last.modified).to eq(
          'title' => 'Another Test'
        )
      end

      it 'should assign method field' do
        post.update_attributes(title: 'Another Test')
        expect(post.history_tracks.last.action).to eq('update')
      end

      it 'should assign original fields' do
        post.update_attributes(title: 'Another Test')
        expect(post.history_tracks.last.original).to eq(
          'title' => 'Test'
        )
      end

      it 'should assign modifier' do
        post.update_attributes(title: 'Another Test')
        expect(post.history_tracks.first.modifier).to eq(user)
      end

      it 'should assign version on history tracks' do
        post.update_attributes(title: 'Another Test')
        expect(post.history_tracks.first.version).to eq(1)
      end

      it 'should assign version on post' do
        post.update_attributes(title: 'Another Test')
        expect(post.version).to eq(1)
      end

      it 'should assign scope' do
        post.update_attributes(title: 'Another Test')
        expect(post.history_tracks.first.scope).to eq('post')
      end

      it 'should assign association_chain' do
        post.update_attributes(title: 'Another Test')
        expect(post.history_tracks.last.association_chain).to eq([{ 'id' => post.id, 'name' => 'Post' }])
      end

      it 'should exclude defined options' do
        name = user.name
        user.update_attributes(name: 'Aaron2', email: 'aaronsnewemail@randomemail.com')
        expect(user.history_tracks.first.original.keys).to eq(['n'])
        expect(user.history_tracks.first.original['n']).to eq(name)
        expect(user.history_tracks.first.modified.keys).to eq(['n'])
        expect(user.history_tracks.first.modified['n']).to eq(user.name)
      end

      it 'should undo field changes' do
        name = user.name
        user.update_attributes(name: 'Aaron2', email: 'aaronsnewemail@randomemail.com')
        user.history_tracks.first.undo! nil
        expect(user.reload.name).to eq(name)
      end

      it 'should undo non-existing field changes' do
        post = Post.create(modifier: user, views: 100)
        expect(post.reload.title).to be_nil
        post.update_attributes(title: 'Aaron2')
        expect(post.reload.title).to eq('Aaron2')
        post.history_tracks.first.undo! nil
        expect(post.reload.title).to be_nil
      end

      it 'should track array changes' do
        aliases = user.aliases
        user.update_attributes(aliases: %w(bob joe))
        expect(user.history_tracks.first.original['aliases']).to eq(aliases)
        expect(user.history_tracks.first.modified['aliases']).to eq(user.aliases)
      end

      it 'should undo array changes' do
        aliases = user.aliases
        user.update_attributes(aliases: %w(bob joe))
        user.history_tracks.first.undo! nil
        expect(user.reload.aliases).to eq(aliases)
      end
    end

    describe '#tracked_changes' do
      context 'create action' do
        subject { tag.history_tracks.first.tracked_changes }
        it 'consider all fields values as :to' do
          expect(subject[:title]).to eq({ to: 'test' }.with_indifferent_access)
        end
      end
      context 'destroy action' do
        subject do
          tag.destroy
          tag.history_tracks.last.tracked_changes
        end
        it 'consider all fields values as :from' do
          expect(subject[:title]).to eq({ from: 'test' }.with_indifferent_access)
        end
      end
      context 'update action' do
        subject { user.history_tracks.first.tracked_changes }
        before do
          user.update_attributes(name: 'Aaron2', email: nil, country: '',  city: nil, phone: '867-5309', aliases: ['', 'bill', 'james'])
        end
        it { is_expected.to be_a HashWithIndifferentAccess }
        it 'should track changed field' do
          expect(subject[:n]).to eq({ from: 'Aaron', to: 'Aaron2' }.with_indifferent_access)
        end
        it 'should track added field' do
          expect(subject[:phone]).to eq({ to: '867-5309' }.with_indifferent_access)
        end
        it 'should track removed field' do
          expect(subject[:city]).to eq({ from: 'Toronto' }.with_indifferent_access)
        end
        it 'should not consider blank as removed' do
          expect(subject[:country]).to eq({ from: 'Canada', to: '' }.with_indifferent_access)
        end
        it 'should track changed array field' do
          expect(subject[:aliases]).to eq({ from: ['bob'], to: ['', 'bill', 'james'] }.with_indifferent_access)
        end
        it 'should not track unmodified field' do
          expect(subject[:address]).to be_nil
        end
        it 'should not track untracked fields' do
          expect(subject[:email]).to be_nil
        end
      end
    end

    describe '#tracked_edits' do
      context 'create action' do
        subject { tag.history_tracks.first.tracked_edits }
        it 'consider all edits as ;add' do
          expect(subject[:add]).to eq({ title: 'test' }.with_indifferent_access)
        end
      end
      context 'destroy action' do
        subject do
          tag.destroy
          tag.history_tracks.last.tracked_edits
        end
        it 'consider all edits as ;remove' do
          expect(subject[:remove]).to eq({ title: 'test' }.with_indifferent_access)
        end
      end
      context 'update action' do
        subject { user.history_tracks.first.tracked_edits }
        before do
          user.update_attributes(name: 'Aaron2', email: nil, country: '', city: nil, phone: '867-5309', aliases: ['', 'bill', 'james'])
        end
        it { is_expected.to be_a HashWithIndifferentAccess }
        it 'should track changed field' do
          expect(subject[:modify]).to eq({ n: { from: 'Aaron', to: 'Aaron2' } }.with_indifferent_access)
        end
        it 'should track added field' do
          expect(subject[:add]).to eq({ phone: '867-5309' }.with_indifferent_access)
        end
        it 'should track removed field and consider blank as removed' do
          expect(subject[:remove]).to eq({ city: 'Toronto', country: 'Canada' }.with_indifferent_access)
        end
        it 'should track changed array field' do
          expect(subject[:array]).to eq({ aliases: { remove: ['bob'], add: ['', 'bill', 'james'] } }.with_indifferent_access)
        end
        it 'should not track unmodified field' do
          %w(add modify remove array).each do |edit|
            expect(subject[edit][:address]).to be_nil
          end
        end
        it 'should not track untracked fields' do
          %w(add modify remove array).each do |edit|
            expect(subject[edit][:email]).to be_nil
          end
        end
      end
      context 'with empty values' do
        subject { Tracker.new }
        it 'should skip empty values' do
          allow(subject).to receive(:tracked_changes) { { name: { to: '', from: [] }, city: { to: 'Toronto', from: '' } } }
          expect(subject.tracked_edits).to eq({ add: { city: 'Toronto' } }.with_indifferent_access)
        end
      end
    end

    describe 'on update non-embedded twice' do
      it 'should assign version on post' do
        post.update_attributes(title: 'Test2')
        post.update_attributes(title: 'Test3')
        expect(post.version).to eq(2)
      end

      it 'should create a history track if changed attributes match tracked attributes' do
        expect do
          post.update_attributes(title: 'Test2')
          post.update_attributes(title: 'Test3')
        end.to change(Tracker, :count).by(2)
      end

      it 'should create a history track of version 2' do
        post.update_attributes(title: 'Test2')
        post.update_attributes(title: 'Test3')
        expect(post.history_tracks.where(version: 2).first).not_to be_nil
      end

      it 'should assign modified fields' do
        post.update_attributes(title: 'Test2')
        post.update_attributes(title: 'Test3')
        expect(post.history_tracks.where(version: 2).first.modified).to eq(
          'title' => 'Test3'
        )
      end

      it 'should assign original fields' do
        post.update_attributes(title: 'Test2')
        post.update_attributes(title: 'Test3')
        expect(post.history_tracks.where(version: 2).first.original).to eq(
          'title' => 'Test2'
        )
      end

      it 'should assign modifier' do
        post.update_attributes(title: 'Another Test', modifier: another_user)
        expect(post.history_tracks.last.modifier).to eq(another_user)
      end
    end

    describe 'on update embedded 1..N (embeds_many)' do
      it 'should assign version on comment' do
        comment.update_attributes(title: 'Test2')
        expect(comment.version).to eq(2) # first track generated on creation
      end

      it 'should create a history track of version 2' do
        comment.update_attributes(title: 'Test2')
        expect(comment.history_tracks.where(version: 2).first).not_to be_nil
      end

      it 'should assign modified fields' do
        comment.update_attributes(t: 'Test2')
        expect(comment.history_tracks.where(version: 2).first.modified).to eq(
          't' => 'Test2'
        )
      end

      it 'should assign original fields' do
        comment.update_attributes(title: 'Test2')
        expect(comment.history_tracks.where(version: 2).first.original).to eq(
          't' => 'test'
        )
      end

      it 'should be possible to undo from parent' do
        comment.update_attributes(title: 'Test 2')
        user
        post.history_tracks.last.undo!(user)
        comment.reload
        expect(comment.title).to eq('test')
      end

      it 'should assign modifier' do
        post.update_attributes(title: 'Another Test', modifier: another_user)
        expect(post.history_tracks.last.modifier).to eq(another_user)
      end
    end

    describe 'on update embedded 1..1 (embeds_one)' do
      let(:section) { Section.new(title: 'Technology') }

      before(:each) do
        post.section = section
        post.save!
        post.reload
        post.section
      end

      it 'should assign version on create section' do
        expect(section.version).to eq(1)
      end

      it 'should assign version on section' do
        section.update_attributes(title: 'Technology 2')
        expect(section.version).to eq(2) # first track generated on creation
      end

      it 'should create a history track of version 2' do
        section.update_attributes(title: 'Technology 2')
        expect(section.history_tracks.where(version: 2).first).not_to be_nil
      end

      it 'should assign modified fields' do
        section.update_attributes(title: 'Technology 2')
        expect(section.history_tracks.where(version: 2).first.modified).to eq(
          't' => 'Technology 2'
        )
      end

      it 'should assign original fields' do
        section.update_attributes(title: 'Technology 2')
        expect(section.history_tracks.where(version: 2).first.original).to eq(
          't' => 'Technology'
        )
      end

      it 'should be possible to undo from parent' do
        section.update_attributes(title: 'Technology 2')
        post.history_tracks.last.undo!(user)
        section.reload
        expect(section.title).to eq('Technology')
      end

      it 'should assign modifier' do
        section.update_attributes(title: 'Business', modifier: another_user)
        expect(post.history_tracks.last.modifier).to eq(another_user)
      end
    end

    describe 'on destroy embedded' do
      it 'should be possible to re-create destroyed embedded' do
        comment.destroy
        comment.history_tracks.last.undo!(user)
        post.reload
        expect(post.comments.first.title).to eq('test')
      end

      it 'should be possible to re-create destroyed embedded from parent' do
        comment.destroy
        post.history_tracks.last.undo!(user)
        post.reload
        expect(post.comments.first.title).to eq('test')
      end

      it 'should be possible to destroy after re-create embedded from parent' do
        comment.destroy
        post.history_tracks.last.undo!(user)
        post.history_tracks.last.undo!(user)
        post.reload
        expect(post.comments.count).to eq(0)
      end

      it 'should be possible to create with redo after undo create embedded from parent' do
        comment # initialize
        post.comments.create!(title: 'The second one')
        track = post.history_tracks.last
        track.undo!(user)
        track.redo!(user)
        post.reload
        expect(post.comments.count).to eq(2)
      end
    end

    describe 'embedded with cascading callbacks' do

      let(:tag_foo) { post.tags.create(title: 'foo', updated_by: user) }
      let(:tag_bar) { post.tags.create(title: 'bar') }

      # it "should have cascaded the creation callbacks and set timestamps" do
      #   tag_foo; tag_bar # initialize
      #   tag_foo.created_at.should_not be_nil
      #   tag_foo.updated_at.should_not be_nil
      # end

      it 'should allow an update through the parent model' do
        update_hash = { 'post' => { 'tags_attributes' => { '1234' => { 'id' => tag_bar.id, 'title' => 'baz' } } } }
        post.update_attributes(update_hash['post'])
        expect(post.tags.last.title).to eq('baz')
      end

      it 'should be possible to destroy through parent model using canoncial _destroy macro' do
        tag_foo
        tag_bar # initialize
        expect(post.tags.count).to eq(2)
        update_hash = { 'post' => { 'tags_attributes' => { '1234' => { 'id' => tag_bar.id, 'title' => 'baz', '_destroy' => 'true' } } } }
        post.update_attributes(update_hash['post'])
        expect(post.tags.count).to eq(1)
        expect(post.history_tracks.to_a.last.action).to eq('destroy')
      end

      it 'should write relationship name for association_chain hiearchy instead of class name when using _destroy macro' do
        update_hash = { 'tags_attributes' => { '1234' => { 'id' => tag_foo.id, '_destroy' => '1' } } }
        post.update_attributes(update_hash)

        # historically this would have evaluated to 'Tags' and an error would be thrown
        # on any call that walked up the association_chain, e.g. 'trackable'
        expect(tag_foo.history_tracks.last.association_chain.last['name']).to eq('tags')
        expect { tag_foo.history_tracks.last.trackable }.not_to raise_error
      end
    end

    describe 'non-embedded' do
      it 'should undo changes' do
        post.update_attributes(title: 'Test2')
        post.history_tracks.where(version: 1).last.undo!(user)
        post.reload
        expect(post.title).to eq('Test')
      end

      it 'should undo destruction' do
        post.destroy
        post.history_tracks.where(version: 1).last.undo!(user)
        expect(Post.find(post.id).title).to eq('Test')
      end

      it 'should create a new history track after undo' do
        comment # initialize
        post.update_attributes(title: 'Test2')
        post.history_tracks.last.undo!(user)
        post.reload
        expect(post.history_tracks.count).to eq(3)
      end

      it 'should assign user as the modifier of the newly created history track' do
        post.update_attributes(title: 'Test2')
        post.history_tracks.where(version: 1).last.undo!(user)
        post.reload
        expect(post.history_tracks.where(version: 2).last.modifier).to eq(user)
      end

      it 'should stay the same after undo and redo' do
        post.update_attributes(title: 'Test2')
        track = post.history_tracks.last
        track.undo!(user)
        track.redo!(user)
        post2 = Post.where(_id: post.id).first

        expect(post.title).to eq(post2.title)
      end

      it 'should be destroyed after undo and redo' do
        post.destroy
        track = post.history_tracks.where(version: 1).last
        track.undo!(user)
        track.redo!(user)
        expect(Post.where(_id: post.id).first).to be_nil
      end
    end

    describe 'embedded' do
      it 'should undo changes' do
        comment.update_attributes(title: 'Test2')
        comment.history_tracks.where(version: 2).first.undo!(user)
        comment.reload
        expect(comment.title).to eq('test')
      end

      it 'should create a new history track after undo' do
        comment.update_attributes(title: 'Test2')
        comment.history_tracks.where(version: 2).first.undo!(user)
        comment.reload
        expect(comment.history_tracks.count).to eq(3)
      end

      it 'should assign user as the modifier of the newly created history track' do
        comment.update_attributes(title: 'Test2')
        comment.history_tracks.where(version: 2).first.undo!(user)
        comment.reload
        expect(comment.history_tracks.where(version: 3).first.modifier).to eq(user)
      end

      it 'should stay the same after undo and redo' do
        comment.update_attributes(title: 'Test2')
        track = comment.history_tracks.where(version: 2).first
        track.undo!(user)
        track.redo!(user)
        comment.reload
        expect(comment.title).to eq('Test2')
      end
    end

    describe 'trackables' do
      before :each do
        comment.update_attributes!(title: 'Test2') # version == 2
        comment.update_attributes!(title: 'Test3') # version == 3
        comment.update_attributes!(title: 'Test4') # version == 4
      end

      describe 'undo' do
        { 'undo'  => [nil], 'undo!' => [nil, :reload] }.each do |test_method, methods|
          methods.each do |method|
            context "#{method || 'instance'}" do
              it 'recognizes :from, :to options' do
                comment.send test_method, user, from: 4, to: 2
                comment.send(method) if method
                expect(comment.title).to eq('test')
              end

              it 'recognizes parameter as version number' do
                comment.send test_method, user, 3
                comment.send(method) if method
                expect(comment.title).to eq('Test2')
              end

              it 'should undo last version when no parameter is specified' do
                comment.send test_method, user
                comment.send(method) if method
                expect(comment.title).to eq('Test3')
              end

              it 'recognizes :last options' do
                comment.send test_method, user, last: 2
                comment.send(method) if method
                expect(comment.title).to eq('Test2')
              end

              if Mongoid::History.mongoid3?
                context 'protected attributes' do
                  before :each do
                    Comment.attr_accessible(nil)
                  end

                  after :each do
                    Comment.attr_protected(nil)
                  end

                  it 'should undo last version when no parameter is specified on protected attributes' do
                    comment.send test_method, user
                    comment.send(method) if method
                    expect(comment.title).to eq('Test3')
                  end

                  it 'recognizes :last options on model with protected attributes' do
                    comment.send test_method, user, last: 2
                    comment.send(method) if method
                    expect(comment.title).to eq('Test2')
                  end
                end
              end
            end
          end
        end
      end

      describe 'redo' do
        [nil, :reload].each do |method|
          context "#{method || 'instance'}" do
            before :each do
              comment.update_attributes(title: 'Test5')
            end

            it 'should recognize :from, :to options' do
              comment.redo! user,  from: 2, to: 4
              comment.send(method) if method
              expect(comment.title).to eq('Test4')
            end

            it 'should recognize parameter as version number' do
              comment.redo! user, 2
              comment.send(method) if method
              expect(comment.title).to eq('Test2')
            end

            it 'should redo last version when no parameter is specified' do
              comment.redo! user
              comment.send(method) if method
              expect(comment.title).to eq('Test5')
            end

            it 'should recognize :last options' do
              comment.redo! user, last: 1
              comment.send(method) if method
              expect(comment.title).to eq('Test5')
            end

            if Mongoid::History.mongoid3?
              context 'protected attributes' do
                before :each do
                  Comment.attr_accessible(nil)
                end

                after :each do
                  Comment.attr_protected(nil)
                end

                it 'should recognize parameter as version number' do
                  comment.redo! user, 2
                  comment.send(method) if method
                  expect(comment.title).to eq('Test2')
                end

                it 'should recognize :from, :to options' do
                  comment.redo! user,  from: 2, to: 4
                  comment.send(method) if method
                  expect(comment.title).to eq('Test4')
                end
              end
            end
          end
        end

      end
    end

    describe 'localized fields' do
      before :each do
        class Sausage
          include Mongoid::Document
          include Mongoid::History::Trackable

          field :flavour, localize: true
          track_history on: [:flavour], track_destroy: true
        end
      end
      it 'should correctly undo and redo' do
        if Sausage.respond_to?(:localized_fields)
          sausage = Sausage.create(flavour_translations: { 'en' => 'Apple', 'nl' => 'Appel' })
          sausage.update_attributes(flavour: 'Guinness')

          track = sausage.history_tracks.last

          track.undo! user
          expect(sausage.reload.flavour).to eq('Apple')

          track.redo! user
          expect(sausage.reload.flavour).to eq('Guinness')

          sausage.destroy
          expect(sausage.history_tracks.last.action).to eq('destroy')
          sausage.history_tracks.last.undo! user
          expect(sausage.reload.flavour).to eq('Guinness')
        end
      end
    end

    describe 'embedded with a polymorphic trackable' do
      let(:foo) { Foo.new(title: 'a title', body: 'a body') }
      before :each do
        post.comments << foo
        post.save
      end
      it 'should assign interface name in association chain' do
        foo.update_attribute(:body, 'a changed body')
        expected_root = { 'name' => 'Post', 'id' => post.id }
        expected_node = { 'name' => 'coms', 'id' => foo.id }
        expect(foo.history_tracks.first.association_chain).to eq([expected_root, expected_node])
      end
    end

    describe '#trackable_parent_class' do
      context 'a non-embedded model' do
        it 'should return the trackable parent class' do
          expect(tag.history_tracks.first.trackable_parent_class).to eq(Tag)
        end
        it 'should return the parent class even if the trackable is deleted' do
          tracker = tag.history_tracks.first
          tag.destroy
          expect(tracker.trackable_parent_class).to eq(Tag)
        end
      end
      context 'an embedded model' do
        it 'should return the trackable parent class' do
          comment.update_attributes(title: 'Foo')
          expect(comment.history_tracks.first.trackable_parent_class).to eq(Post)
        end
        it 'should return the parent class even if the trackable is deleted' do
          tracker = comment.history_tracks.first
          comment.destroy
          expect(tracker.trackable_parent_class).to eq(Post)
        end
      end
    end

    describe 'when default scope is present' do
      before do
        class Post
          default_scope -> { where(title: nil) }
        end
        class Comment
          default_scope -> { where(title: nil) }
        end
        class User
          default_scope -> { where(name: nil) }
        end
        class Tag
          default_scope -> { where(title: nil) }
        end
      end

      describe 'post' do

        it 'should correctly undo and redo' do
          post.update_attributes(title: 'a new title')
          track = post.history_tracks.last
          track.undo! user
          expect(post.reload.title).to eq('Test')
          track.redo! user
          expect(post.reload.title).to eq('a new title')
        end

        it 'should stay the same after undo and redo' do
          post.update_attributes(title: 'testing')
          track = post.history_tracks.last
          track.undo! user
          track.redo! user
          expect(post.reload.title).to eq('testing')
        end
      end
      describe 'comment' do
        it 'should correctly undo and redo' do
          comment.update_attributes(title: 'a new title')
          track = comment.history_tracks.last
          track.undo! user
          expect(comment.reload.title).to eq('test')
          track.redo! user
          expect(comment.reload.title).to eq('a new title')
        end

        it 'should stay the same after undo and redo' do
          comment.update_attributes(title: 'testing')
          track = comment.history_tracks.last
          track.undo! user
          track.redo! user
          expect(comment.reload.title).to eq('testing')
        end
      end
      describe 'user' do
        it 'should correctly undo and redo' do
          user.update_attributes(name: 'a new name')
          track = user.history_tracks.last
          track.undo! user
          expect(user.reload.name).to eq('Aaron')
          track.redo! user
          expect(user.reload.name).to eq('a new name')
        end

        it 'should stay the same after undo and redo' do
          user.update_attributes(name: 'testing')
          track = user.history_tracks.last
          track.undo! user
          track.redo! user
          expect(user.reload.name).to eq('testing')
        end
      end
      describe 'tag' do
        it 'should correctly undo and redo' do
          tag.update_attributes(title: 'a new title')
          track = tag.history_tracks.last
          track.undo! user
          expect(tag.reload.title).to eq('test')
          track.redo! user
          expect(tag.reload.title).to eq('a new title')
        end

        it 'should stay the same after undo and redo' do
          tag.update_attributes(title: 'testing')
          track = tag.history_tracks.last
          track.undo! user
          track.redo! user
          expect(tag.reload.title).to eq('testing')
        end
      end
    end

    describe 'overriden changes_method with additional fields' do
      before :each do
        class OverriddenChangesMethod
          include Mongoid::Document
          include Mongoid::History::Trackable

          track_history on: [:foo], changes_method: :my_changes

          def my_changes
            { foo: %w(bar baz) }
          end
        end
      end

      it 'should add foo to the changes history' do
        o = OverriddenChangesMethod.create
        o.save
        track = o.history_tracks.last
        expect(track.modified).to eq('foo' => 'baz')
        expect(track.original).to eq('foo' => 'bar')
      end
    end
  end
end
