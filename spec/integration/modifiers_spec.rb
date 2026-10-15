require 'spec_helper'

describe 'Modifier configuration' do
  before do
    class User
      include Mongoid::Document
      field :name, type: String
    end

    class ModifierTracker
      include Mongoid::History::Tracker
    end
    Mongoid::History.tracker_class_name = 'ModifierTracker'

    class ModifierPost
      include Mongoid::Document
      include Mongoid::History::Trackable
      field :title, type: String
      track_history modifier_field_optional: true
    end
  end

  after do
    ModifierTracker.delete_all
    SnapshotTracker.delete_all if Object.const_defined?(:SnapshotTracker)
    %i[User ModifierPost ModifierlessPost RenamedModifierPost SnapshotTracker ModifierTracker
       ModifierContainer EmbeddedModifierPost].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end
  end

  let(:alice) { User.create!(name: 'Alice') }
  let(:bob) { User.create!(name: 'Bob') }

  it 'uses the current scope on create, update and destroy, not the previous saved modifier' do
    post = Mongoid::History.with_modifier(alice) { ModifierPost.create!(title: 'First') }
    Mongoid::History.with_modifier(bob) { post.update_attributes!(title: 'Second') }
    Mongoid::History.with_modifier(alice) { post.destroy }

    expect(ModifierTracker.asc(:version).map(&:modifier)).to eq([alice, bob, alice])
  end

  it 'sets the modifier before required association validation' do
    ModifierPost.validates :modifier, presence: true
    post = Mongoid::History.with_modifier(alice) { ModifierPost.create!(title: 'First') }
    expect(post.reload.modifier).to eq(alice)
  end

  it 'keeps explicit assignment behavior outside a scope' do
    post = ModifierPost.create!(title: 'First', modifier: alice)
    post.update_attributes!(title: 'Second', modifier: bob)
    expect(post.history_tracks.map(&:modifier)).to eq([alice, bob])
  end

  it 'uses an explicit nil scope instead of a stale saved modifier' do
    post = ModifierPost.create!(title: 'First', modifier: alice)
    Mongoid::History.with_modifier(nil) { post.update_attributes!(title: 'Anonymous') }
    expect(post.history_tracks.last.modifier).to be_nil
  end

  it 'does not skip anonymous history by default' do
    post = ModifierPost.create!(title: 'Anonymous')
    expect(post.history_tracks.count).to eq(1)
    expect(post.history_tracks.first.modifier).to be_nil
  end

  it 'does not create a modifier association when modifier_field is nil, including undo and redo' do
    class ModifierlessPost
      include Mongoid::Document
      include Mongoid::History::Trackable
      field :title, type: String
      track_history modifier_field: nil
    end
    post = Mongoid::History.with_modifier(alice) { ModifierlessPost.create!(title: 'First') }
    post.update_attributes!(title: 'Second')
    post.history_tracks.last.undo!
    expect(post.reload.title).to eq('First')
    post.history_tracks.where(version: 2).first.redo!
    expect(post.reload.title).to eq('Second')
    expect(ModifierlessPost.relations).not_to have_key('modifier')
    expect(ModifierTracker.all.map(&:modifier).compact).to be_empty
  end

  it 'keeps the shared tracker modifier name when the model uses a custom name' do
    class RenamedModifierPost
      include Mongoid::Document
      include Mongoid::History::Trackable
      field :title, type: String
      track_history modifier_field: :updater, modifier_field_optional: true
    end
    post = Mongoid::History.with_modifier(alice) { RenamedModifierPost.create!(title: 'First') }
    expect(post.updater).to eq(alice)
    expect(post.history_tracks.first.modifier).to eq(alice)
    post.update_attributes!(title: 'Second')
    post.history_tracks.last.undo!(bob)
    expect(post.reload.updater).to eq(bob)
  end

  it 'supports durable string snapshots through tracker callbacks without changing the association schema' do
    class SnapshotTracker
      include Mongoid::History::Tracker
      field :modifier_name, type: String
      before_create do
        self.modifier_name = modifier.name if modifier
      end
    end
    ModifierPost.track_history modifier_field_optional: true, tracker_class_name: SnapshotTracker
    ModifierPost.clear_trackable_memoization
    post = ModifierPost.create!(title: 'First', modifier: alice)
    track = post.history_tracks.first
    alice.destroy
    expect(track.reload.modifier_name).to eq('Alice')
    expect(track.modifier).to be_nil
  end
end
