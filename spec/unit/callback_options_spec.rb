require 'spec_helper'

describe Mongoid::History::Options do
  describe ':if' do
    let(:dummy_model) do
      Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        store_in collection: :model_ones
        field :foo
        attr_accessor :bar
        track_history track_create: true,
                      track_update: true,
                      track_destroy: true,
                      modifier_field_optional: true,
                      if: :bar
        def self.name
          'DummyModel'
        end
      end
    end
    let(:obj) { dummy_model.new(foo: 'Foo') }

    context 'when condition evaluates to true' do
      before { obj.bar = true }
      it 'should create history tracks' do
        expect { obj.save }.to change(Tracker, :count).by(1)
        expect do
          obj.update_attributes(foo: 'Foo-2')
        end.to change(Tracker, :count).by(1)
        expect { obj.destroy }.to change(Tracker, :count).by(1)
      end
    end

    context 'when condition evaluates to false' do
      before { obj.bar = false }
      it 'should not create history tracks' do
        expect { obj.save }.to_not change(Tracker, :count)
        expect do
          obj.update_attributes(foo: 'Foo-2')
        end.to_not change(Tracker, :count)
        expect { obj.destroy }.to_not change(Tracker, :count)
      end
    end
  end

  describe ':unless' do
    let(:dummy_model) do
      Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        store_in collection: :model_ones
        field :foo
        attr_accessor :bar
        track_history track_create: true,
                      track_update: true,
                      track_destroy: true,
                      modifier_field_optional: true,
                      unless: ->(obj) { obj.bar }
        def self.name
          'DummyModel'
        end
      end
    end
    let(:obj) { dummy_model.new(foo: 'Foo') }

    context 'when condition evaluates to true' do
      before { obj.bar = true }
      it 'should not create history tracks' do
        expect { obj.save }.to_not change(Tracker, :count)
        expect do
          obj.update_attributes(foo: 'Foo-2')
        end.to_not change(Tracker, :count)
        expect { obj.destroy }.to_not change(Tracker, :count)
      end
    end

    context 'when condition evaluates to false' do
      before { obj.bar = false }
      it 'should create history tracks' do
        expect { obj.save }.to change(Tracker, :count).by(1)
        expect do
          obj.update_attributes(foo: 'Foo-2')
        end.to change(Tracker, :count).by(1)
        expect { obj.destroy }.to change(Tracker, :count).by(1)
      end
    end
  end

  describe ':if and :unless' do
    let(:dummy_model) do
      Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        store_in collection: :model_ones
        field :foo
        attr_accessor :bar, :baz
        track_history track_create: true,
                      track_update: true,
                      track_destroy: true,
                      modifier_field_optional: true,
                      if: :bar, unless: ->(obj) { obj.baz }
        def self.name
          'DummyModel'
        end
      end
    end
    let(:obj) { dummy_model.new(foo: 'Foo') }

    context 'when :if condition evaluates to true' do
      before { obj.bar = true }

      context 'and :unless condition evaluates to true' do
        before { obj.baz = true }
        it 'should not create history tracks' do
          expect { obj.save }.to_not change(Tracker, :count)
          expect do
            obj.update_attributes(foo: 'Foo-2')
          end.to_not change(Tracker, :count)
          expect { obj.destroy }.to_not change(Tracker, :count)
        end
      end

      context 'and :unless condition evaluates to false' do
        before { obj.baz = false }
        it 'should create history tracks' do
          expect { obj.save }.to change(Tracker, :count).by(1)
          expect do
            obj.update_attributes(foo: 'Foo-2')
          end.to change(Tracker, :count).by(1)
          expect { obj.destroy }.to change(Tracker, :count).by(1)
        end
      end
    end

    context 'when :if condition evaluates to false' do
      before { obj.bar = false }

      context 'and :unless condition evaluates to true' do
        before { obj.baz = true }
        it 'should not create history tracks' do
          expect { obj.save }.to_not change(Tracker, :count)
          expect do
            obj.update_attributes(foo: 'Foo-2')
          end.to_not change(Tracker, :count)
          expect { obj.destroy }.to_not change(Tracker, :count)
        end
      end

      context 'and :unless condition evaluates to false' do
        before { obj.baz = false }
        it 'should not create history tracks' do
          expect { obj.save }.to_not change(Tracker, :count)
          expect do
            obj.update_attributes(foo: 'Foo-2')
          end.to_not change(Tracker, :count)
          expect { obj.destroy }.to_not change(Tracker, :count)
        end
      end
    end
  end
end
