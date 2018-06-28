require 'spec_helper'

describe Mongoid::History::Tracker do
  context 'when included' do
    before :each do
      Mongoid::History.tracker_class_name = nil

      class MyTracker
        include Mongoid::History::Tracker
      end
    end

    after :each do
      Object.send(:remove_const, :MyTracker)
    end

    it 'should set tracker_class_name when included' do
      expect(Mongoid::History.tracker_class_name).to eq(:my_tracker)
    end

    it 'should set fields defaults' do
      expect(MyTracker.new.association_chain).to eq([])
      expect(MyTracker.new.original).to eq({})
      expect(MyTracker.new.modified).to eq({})
    end
  end

  describe '#tracked_edits' do
    before :each do
      class TrackerOne
        include Mongoid::History::Tracker
      end

      class ModelOne
        include Mongoid::Document
        include Mongoid::History::Trackable

        store_in collection: :model_ones

        if Mongoid::Compatibility::Version.mongoid7_or_newer?
          embeds_many :emb_ones
        else
          embeds_many :emb_ones, inverse_class_name: 'EmbOne'
        end
      end

      class EmbOne
        include Mongoid::Document

        field :em_foo
        embedded_in :model_one
      end
    end

    after :each do
      Object.send(:remove_const, :TrackerOne)
      Object.send(:remove_const, :ModelOne)
      Object.send(:remove_const, :EmbOne)
    end

    context 'when embeds_many' do
      before :each do
        ModelOne.track_history(on: :emb_ones)
        allow(tracker).to receive(:trackable_parent_class) { ModelOne }
      end

      let(:tracker) { TrackerOne.new }

      describe '#prepare_tracked_edits_for_embeds_many' do
        before :each do
          allow(tracker).to receive(:tracked_changes) { changes }
        end

        let(:emb_one) { EmbOne.new }
        let(:emb_one_2) { EmbOne.new }
        let(:emb_one_3) { EmbOne.new }
        let(:changes) { {} }

        subject { tracker.tracked_edits['embeds_many']['emb_ones'] }

        context 'when all values present' do
          let(:changes) do
            {
              'emb_ones' => {
                from: [{ '_id' => emb_one._id, 'em_foo' => 'Em-Foo' },
                       { '_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2' }],
                to: [{ '_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2-new' },
                     { '_id' => emb_one_3._id, 'em_foo' => 'Em-Foo-3' }]
              }
            }
          end

          it 'should include :add, :remove, and :modify' do
            expect(subject['add']).to eq [{ '_id' => emb_one_3._id, 'em_foo' => 'Em-Foo-3' }]
            expect(subject['remove']).to eq [{ '_id' => emb_one._id, 'em_foo' => 'Em-Foo' }]
            expect(subject['modify'].size).to eq 1
            expect(subject['modify'][0]['from']).to eq('_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2')
            expect(subject['modify'][0]['to']).to eq('_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2-new')
          end
        end

        context 'when value :from blank' do
          let(:changes) do
            {
              'emb_ones' => {
                to: [{ '_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2-new' },
                     { '_id' => emb_one_3._id, 'em_foo' => 'Em-Foo-3' }]
              }
            }
          end
          it 'should include :add' do
            expect(subject['add'].size).to eq 2
            expect(subject['add'][0]).to eq('_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2-new')
            expect(subject['add'][1]).to eq('_id' => emb_one_3._id, 'em_foo' => 'Em-Foo-3')
            expect(subject['remove']).to be_nil
            expect(subject['modify']).to be_nil
          end
        end

        context 'when value :to blank' do
          let(:changes) do
            {
              'emb_ones' => {
                from: [{ '_id' => emb_one._id, 'em_foo' => 'Em-Foo' },
                       { '_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2' }]
              }
            }
          end
          it 'should include :remove' do
            expect(subject['add']).to be_nil
            expect(subject['modify']).to be_nil
            expect(subject['remove'].size).to eq 2
            expect(subject['remove'][0]).to eq('_id' => emb_one._id, 'em_foo' => 'Em-Foo')
            expect(subject['remove'][1]).to eq('_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2')
          end
        end

        context 'when no id common in :from and :to' do
          let(:changes) do
            {
              'emb_ones' => {
                from: [{ '_id' => emb_one._id, 'em_foo' => 'Em-Foo' }],
                to: [{ '_id' => emb_one_3._id, 'em_foo' => 'Em-Foo-3' }]
              }
            }
          end
          it 'should include :add, and :remove' do
            expect(subject['add']).to eq [{ '_id' => emb_one_3._id, 'em_foo' => 'Em-Foo-3' }]
            expect(subject['modify']).to be_nil
            expect(subject['remove']).to eq [{ '_id' => emb_one._id, 'em_foo' => 'Em-Foo' }]
          end
        end

        context 'when _id attribute not set' do
          let(:changes) do
            {
              'emb_ones' => {
                from: [{ 'em_foo' => 'Em-Foo' },
                       { '_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2' }],
                to: [{ 'em_foo' => 'Em-Foo-2-new' },
                     { 'em_foo' => 'Em-Foo-3' }]
              }
            }
          end
          it 'should include :add, and :remove' do
            expect(subject['add']).to eq([{ 'em_foo' => 'Em-Foo-2-new' }, { 'em_foo' => 'Em-Foo-3' }])
            expect(subject['modify']).to be_nil
            expect(subject['remove']).to eq [{ 'em_foo' => 'Em-Foo' }, { '_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2' }]
          end
        end

        context 'when no change in an object' do
          let(:changes) do
            {
              'emb_ones' => {
                from: [{ '_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2' }],
                to: [{ '_id' => emb_one_2._id, 'em_foo' => 'Em-Foo-2' }]
              }
            }
          end
          it 'should include not :add, :remove, and :modify' do
            expect(subject['add']).to be_nil
            expect(subject['modify']).to be_nil
            expect(subject['remove']).to be_nil
          end
        end
      end
    end
  end
end
