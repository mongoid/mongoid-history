require 'spec_helper'

describe 'Embedded history regressions' do
  before do
    class User
      include Mongoid::Document
    end

    class EmbeddedHistoryChild
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :body, type: String
      field :secret, type: String
      embedded_in :owner, polymorphic: true

      track_history on: :body, scope: :owner,
                    modifier_field_inverse_of: nil
    end

    class EmbeddedHistoryParent
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      embeds_many :children, class_name: 'EmbeddedHistoryChild', as: :owner, cascade_callbacks: true
      embeds_one :child, class_name: 'EmbeddedHistoryChild', as: :owner, cascade_callbacks: true
      accepts_nested_attributes_for :children, :child

      track_history on: [:name, { children: %i[_id body] }, { child: :body }],
                    modifier_field: nil
    end
  end

  after do
    Object.send(:remove_const, :EmbeddedHistoryParent)
    Object.send(:remove_const, :EmbeddedHistoryChild)
    Object.send(:remove_const, :User)
  end

  let(:user) { User.create! }
  let(:other_user) { User.create! }
  let(:parent) { EmbeddedHistoryParent.create!(name: 'parent') }
  let(:parent_tracks) { parent.history_tracks.where('association_chain.1' => { '$exists' => false }) }

  it 'summarizes child fields using the child whitelist, even after deletion' do
    child = parent.children.create!(body: 'before', modifier: user)
    child.update_attributes!(body: 'after')
    track = child.history_tracks.last
    expect(track.tracked_edits[:modify]).to eq('body' => { 'from' => 'before', 'to' => 'after' })
    child.destroy
    expect(track.reload.tracked_changes['body']).to eq('from' => 'before', 'to' => 'after')
  end

  it 'tracks only permitted child fields when saving the parent' do
    parent.build_child(body: 'before', secret: 'private', modifier: user).save!
    parent.reload
    parent.child.body = 'after'
    parent.child.secret = 'still private'
    parent.save!
    track = parent_tracks.last
    expect(track.original['child']).to eq('body' => 'before')
    expect(track.modified['child']).to eq('body' => 'after')
  end

  it 'does not create a parent history entry for an untracked child edit' do
    parent.build_child(body: 'before', secret: 'private', modifier: user).save!
    parent.reload
    count = parent_tracks.count
    parent.child.secret = 'not tracked'
    parent.save!
    expect(parent_tracks.count).to eq(count)
    expect(parent.reload.child.secret).to eq('not tracked')
  end

  it 'tracks edits to an embeds_many child in parent history without changing siblings' do
    child = parent.children.create!(body: 'before', modifier: user)
    sibling = parent.children.create!(body: 'sibling', modifier: user)
    parent.reload
    parent.children_attributes = [{ id: child.id, body: 'after' }]
    parent.save!
    track = parent_tracks.last
    expect(track.original['children']).to eq([
                                               { '_id' => child.id, 'body' => 'before' }, { '_id' => sibling.id, 'body' => 'sibling' }
                                             ])
    expect(track.modified['children']).to eq([
                                               { '_id' => child.id, 'body' => 'after' }, { '_id' => sibling.id, 'body' => 'sibling' }
                                             ])
    expect(parent.reload.children.count).to eq(2)
    expect(parent.children.first.body).to eq('after')
  end

  it 'combines parent and embedded changes without overwriting either' do
    parent.children.create!(body: 'before', modifier: user)
    parent.reload
    parent.name = 'renamed'
    parent.children.first.body = 'after'
    parent.save!
    track = parent_tracks.last
    expect(track.original['name']).to eq('parent')
    expect(track.modified['name']).to eq('renamed')
    expect(track.original['children'].first['body']).to eq('before')
    expect(track.modified['children'].first['body']).to eq('after')
  end

  it 'versions each embedded document independently instead of updating its parent counter' do
    first = parent.children.create!(body: 'first', modifier: user)
    second = parent.children.create!(body: 'second', modifier: user)
    first.update_attributes!(body: 'changed')
    expect(first.reload.version).to eq(2)
    expect(second.reload.version).to eq(1)
    expect(parent.reload.version).to eq(1)
    expect(first.history_tracks.pluck(:version)).to eq([1, 2])
    expect(second.history_tracks.pluck(:version)).to eq([1])
  end

  it 'tracks adding children to a persisted parent whose original relation is nil' do
    parent.write_attribute('children', [EmbeddedHistoryChild.new(body: 'new', modifier: user).attributes])
    expect(parent.changes['children'].first).to be_nil
    parent.save!
    track = parent_tracks.last
    expect(track.modified['children'].first['body']).to eq('new')
  end

  it 'returns a restored standalone document when undo! is called on a destroyed instance' do
    id = parent.id
    parent.destroy
    restored = parent.undo!
    expect(restored.id).to eq(id)
    expect(restored.name).to eq('parent')
    expect(EmbeddedHistoryParent.find(id).name).to eq('parent')
  end

  it 'returns a restored embedded document when undo! is called on a destroyed instance' do
    child = parent.children.create!(body: 'before', modifier: user)
    child.destroy
    restored = child.undo!(other_user)
    expect(restored.id).to eq(child.id)
    expect(restored.body).to eq('before')
    expect(parent.reload.children.first.modifier_id).to eq(other_user.id)
  end

  it 'continues only the restored document counter, not a higher child counter' do
    creation = parent_tracks.first
    child = parent.children.create!(body: 'before', modifier: user)
    3.times { |index| child.update_attributes!(body: index.to_s) }
    parent.destroy
    restored = creation.reload.redo!
    expect(restored.id).to eq(parent.id)
    expect(restored.version).to eq(3)
  end

  it 'runs child tracking callbacks for nested polymorphic attributes' do
    parent.child_attributes = { body: 'initial', modifier: user }
    parent.save!
    parent.reload
    parent.child_attributes = { body: 'updated' }
    parent.save!
    expect(parent.child.history_tracks.last.modified['body']).to eq('updated')
    expect(parent.child.history_tracks.last.version).to eq(2)
    expect(parent.child.history_tracks.last.scope).to eq('embedded_history_parent')
  end

  %i[child children].each do |relation|
    it "passes the modifier when undoing and redoing a destroyed #{relation}" do
      child = if relation == :child
                parent.build_child(body: 'before', modifier: user).tap(&:save!)
              else
                parent.children.create!(body: 'before', modifier: user)
              end
      child.destroy
      track = child.history_tracks.last
      track.undo!(other_user)
      restored = parent.reload.public_send(relation)
      restored = restored.first if relation == :children
      expect(restored.modifier).to eq(other_user)
      expect(restored.history_tracks.last.modifier_id).to eq(other_user.id)
      track.reload.redo!(user)
      expect(child.history_tracks.last.modifier_id).to eq(user.id)
    end

    it "preserves attributes and identity when undoing and redoing a created #{relation}" do
      child = if relation == :child
                parent.build_child(body: 'created', modifier: user).tap(&:save!)
              else
                parent.children.create!(body: 'created', modifier: user)
              end
      track = child.history_tracks.first
      track.undo!(other_user)
      track.reload.redo!(user)
      restored = parent.reload.public_send(relation)
      restored = restored.first if relation == :children
      expect(restored.id).to eq(child.id)
      expect(restored.body).to eq('created')
      expect(restored.modifier_id).to eq(user.id)
      expect(restored.history_tracks.pluck(:version)).to eq([1, 2, 3])
    end
  end
end
