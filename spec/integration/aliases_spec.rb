require 'spec_helper'

describe 'Stable trackable aliases' do
  before do
    class OriginalAliasedDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      store_in collection: :renamable_documents
      field :title
      track_history as: 'stable_document', modifier_field: nil
    end
  end

  after do
    %i[OriginalAliasedDocument RenamedAliasedDocument AliasedSubclass ConflictingAliasedDocument AliasedChild].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end
  end

  it 'stores the alias as root identity and default scope' do
    document = OriginalAliasedDocument.create!(title: 'first')
    track = document.history_tracks.last.reload
    expect(track.association_chain.first['name']).to eq('stable_document')
    expect(track.scope).to eq('stable_document')
    expect(track.trackable_parent_class).to eq(OriginalAliasedDocument)
    expect(track.trackable).to eq(document)
  end

  it 'resolves old history after a rename, including undo, redo and destroy restoration' do
    document = OriginalAliasedDocument.create!(title: 'first')
    document.update_attributes!(title: 'second')
    id = document.id
    Object.send(:remove_const, :OriginalAliasedDocument)

    class RenamedAliasedDocument
      include Mongoid::Document
      include Mongoid::History::Trackable

      store_in collection: :renamable_documents
      field :title
      track_history as: 'stable_document', modifier_field: nil
    end

    renamed = RenamedAliasedDocument.find(id)
    expect(renamed.history_tracks.count).to eq(2)
    track = renamed.history_tracks.last.reload
    expect(track.trackable_parent_class).to eq(RenamedAliasedDocument)
    track.undo!
    expect(renamed.reload.title).to eq('first')
    track.redo!
    expect(renamed.reload.title).to eq('second')
    renamed.destroy
    destroy_track = Tracker.where(action: 'destroy').last.reload
    destroy_track.undo!
    expect(RenamedAliasedDocument.find(id).title).to eq('second')
  end

  it 'honors an explicit scope without changing the alias' do
    OriginalAliasedDocument.track_history as: :stable_document, scope: :explicit, modifier_field: nil
    document = OriginalAliasedDocument.create!(title: 'first')
    track = document.history_tracks.last.reload
    expect(track.scope).to eq('explicit')
    expect(track.association_chain.first['name']).to eq('stable_document')
  end

  it 'does not give subclasses the same concrete identity as their parent' do
    class AliasedSubclass < OriginalAliasedDocument
      field :extra
    end

    document = AliasedSubclass.create!(title: 'first', extra: 'subclass')
    track = document.history_tracks.last.reload
    expect(track.association_chain.first['name']).to eq('AliasedSubclass')
    expect(track.trackable_parent_class).to eq(AliasedSubclass)
    expect(track.modified['extra']).to eq('subclass')
  end

  it 'rejects collisions and blank identities rather than silently resolving the wrong model' do
    class ConflictingAliasedDocument
      include Mongoid::Document
      include Mongoid::History::Trackable
    end

    expect { ConflictingAliasedDocument.track_history as: 'stable_document' }.to raise_error(ArgumentError, /already used/)
    expect { ConflictingAliasedDocument.track_history as: 'OriginalAliasedDocument' }.to raise_error(ArgumentError, /already used/)
    expect { ConflictingAliasedDocument.track_history as: '' }.to raise_error(ArgumentError, /nonempty/)
  end

  it 'continues to resolve legacy class-name history when no alias was used' do
    track = Tracker.new(association_chain: [{ 'name' => 'OriginalAliasedDocument' }])
    expect(track.trackable_parent_class).to eq(OriginalAliasedDocument)
  end

  it 'resolves embedded association chains through the root alias' do
    class AliasedChild
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :body
      embedded_in :original_aliased_document, inverse_of: :aliased_children
      track_history scope: :stable_document, modifier_field: nil
    end

    OriginalAliasedDocument.embeds_many :aliased_children, class_name: 'AliasedChild', inverse_of: :original_aliased_document
    document = OriginalAliasedDocument.create!(title: 'parent')
    child = document.aliased_children.create!(body: 'child')
    track = Tracker.where('association_chain.name' => 'aliased_children').last.reload
    expect(track.association_chain.map { |node| node['name'] }).to eq(%w[stable_document aliased_children])
    expect(track.trackable).to eq(child)
    expect(track.trackable_parent).to eq(document)
  end
end
