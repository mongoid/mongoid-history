require 'spec_helper'

describe 'Historical association boundaries' do
  before do
    stub_const('HistoryCoverageRoot', Class.new)
    HistoryCoverageRoot.class_eval do
      include Mongoid::Document
      include Mongoid::History::Trackable
      field :name, type: String
      embeds_many :children, class_name: 'HistoryCoverageChild'
      track_history on: [:name], modifier_field: nil
    end
    stub_const('HistoryCoverageChild', Class.new)
    HistoryCoverageChild.class_eval do
      include Mongoid::Document
      field :name, type: String
      embedded_in :root, class_name: 'HistoryCoverageRoot', inverse_of: :children
    end
  end

  let(:root) { HistoryCoverageRoot.create!(name: 'root') }

  it 'resolves and caches the root and parent chain of an embedded record' do
    child = root.children.create!(name: 'child')
    tracker = Tracker.new(association_chain: [
                            { 'name' => 'history_coverage_roots', 'id' => root.id },
                            { 'name' => 'children', 'id' => child.id }
                          ])

    expect(tracker.trackable_root).to eq(root)
    expect(tracker.trackable_root).to equal(tracker.trackable_root)
    expect(tracker.trackable_parents).to eq([root])
    expect(tracker.trackable_parents).to equal(tracker.trackable_parents)
    expect(tracker.trackable).to eq(child)
  end

  it 'rejects an undo selector without a range or last count' do
    expect { root.undo(nil, unexpected: true) }
      .to raise_error(RuntimeError, /Invalid options, please specify/)
  end

  it 'returns an empty parent chain for a root document' do
    tracker = Tracker.new(association_chain: [
                            { 'name' => 'history_coverage_roots', 'id' => root.id }
                          ])

    expect(tracker.trackable_root).to eq(root)
    expect(tracker.trackable_parents).to eq([])
  end

  it 'reports corrupt history that names a scalar field as an association' do
    tracker = Tracker.new(association_chain: [
                            { 'name' => 'history_coverage_roots', 'id' => root.id },
                            { 'name' => 'name', 'id' => root.id }
                          ])

    expect { tracker.trackable }
      .to raise_error(RuntimeError, /Unexpected relation for field 'name': nil/)
  end
end
