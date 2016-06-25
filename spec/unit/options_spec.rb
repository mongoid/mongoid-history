require 'spec_helper'

describe Mongoid::History::Options do
  before :all do
    MyOptionsModel = Class.new do
      include Mongoid::Document
      include Mongoid::History::Trackable
      store_in collection: :my_options_models
      field :foo
      field :bar
      embeds_many :my_options_embed_many_models, inverse_class_name: 'MyOptionsEmbedManyModel'
      embeds_many :my_options_embed_many_two_models, store_as: :emtwo, inverse_class_name: 'MyOptionsEmbedManyTwoModel'
    end

    MyOptionsEmbedManyModel = Class.new do
      include Mongoid::Document
      field :baz
      embedded_in :my_options_model
    end

    MyOptionsEmbedManyTwoModel = Class.new do
      include Mongoid::Document
      field :baz_two
      embedded_in :my_options_model
    end
  end

  let(:service) { described_class.new(MyOptionsModel) }

  subject { service }

  it { is_expected.to respond_to :trackable }
  it { is_expected.to respond_to :options }

  describe '#initialize' do
    it { expect(service.trackable).to eq MyOptionsModel }
  end

  describe '#scope' do
    it { expect(service.scope).to eq :my_options_model }
  end

  describe '#default_options' do
    let(:expected_options) do
      { on: :all,
        except: [:created_at, :updated_at],
        modifier_field: :modifier,
        version_field: :version,
        changes_method: :changes,
        scope: :my_options_model,
        track_create: false,
        track_update: true,
        track_destroy: false }
    end
    it { expect(service.default_options).to eq expected_options }
  end

  describe '#parse' do
    context 'when options not passed' do
      let(:expected_options) do
        { on: %w(fields),
          except: %w(created_at updated_at),
          modifier_field: :modifier,
          version_field: :version,
          changes_method: :changes,
          scope: :my_options_model,
          track_create: false,
          track_update: true,
          track_destroy: false,
          tracked_fields: %w(foo bar),
          tracked_relations: [],
          tracked_dynamic: [] }
      end
      it { expect(service.parse).to eq expected_options }
    end

    context 'when options passed' do
      subject { service.parse(options) }

      describe ':on' do
        let(:options) { { on: value } }

        context 'with :fields' do
          let(:value) { :fields }
          it { expect(subject[:on]).to eq %w(fields) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_dynamic]).to eq [] }
        end

        context 'with :foo' do
          let(:value) { :foo }
          it { expect(subject[:on]).to eq %w(foo) }
          it { expect(subject[:tracked_fields]).to eq %w(foo) }
          it { expect(subject[:tracked_dynamic]).to eq [] }
        end

        context 'with [:foo]' do
          let(:value) { [:foo] }
          it { expect(subject[:on]).to eq %w(foo) }
          it { expect(subject[:tracked_fields]).to eq %w(foo) }
          it { expect(subject[:tracked_dynamic]).to eq [] }
        end

        context 'with :my_options_embed_many_models' do
          let(:value) { :my_options_embed_many_models }
          it { expect(subject[:on]).to eq %w(my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq [] }
          it { expect(subject[:tracked_relations]).to eq %w(my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_options_embed_many_models) }
        end

        context 'with [:my_options_embed_many_models]' do
          let(:value) { [:my_options_embed_many_models] }
          it { expect(subject[:on]).to eq %w(my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq [] }
          it { expect(subject[:tracked_relations]).to eq %w(my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_options_embed_many_models) }
        end

        context 'with [:my_options_embed_many_models, :my_options_embed_many_two_models]' do
          let(:value) { [:my_options_embed_many_models, :my_options_embed_many_two_models] }
          it { expect(subject[:on]).to eq %w(my_options_embed_many_models emtwo) }
          it { expect(subject[:tracked_fields]).to eq [] }
          it { expect(subject[:tracked_relations]).to eq %w(my_options_embed_many_models emtwo) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_options_embed_many_models emtwo) }
        end

        context 'with [:all, :my_options_embed_many_models]' do
          let(:value) { [:all, :my_options_embed_many_models] }
          it { expect(subject[:on]).to eq %w(fields my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_options_embed_many_models) }
        end

        context 'with [:fields, :my_options_embed_many_models]' do
          let(:value) { [:all, :my_options_embed_many_models] }
          it { expect(subject[:on]).to eq %w(fields my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_options_embed_many_models) }
        end

        context 'with [:foo, :my_options_embed_many_models]' do
          let(:value) { [:foo, :my_options_embed_many_models] }
          it { expect(subject[:on]).to eq %w(foo my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq %w(foo) }
          it { expect(subject[:tracked_relations]).to eq %w(my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_options_embed_many_models) }
        end

        context 'with [:foo, :bar, :my_options_embed_many_models]' do
          let(:value) { [:foo, :bar, :my_options_embed_many_models] }
          it { expect(subject[:on]).to eq %w(foo bar my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_options_embed_many_models) }
        end

        context 'with [:foo, :bar, :my_options_embed_many_models, :my_options_embed_many_two_models]' do
          let(:value) { [:foo, :bar, :my_options_embed_many_models, :my_options_embed_many_two_models] }
          it { expect(subject[:on]).to eq %w(foo bar my_options_embed_many_models emtwo) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_options_embed_many_models emtwo) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_options_embed_many_models emtwo) }
        end

        context 'with :my_dynamic_field' do
          let(:value) { :my_dynamic_field }
          it { expect(subject[:on]).to eq %w(my_dynamic_field) }
          it { expect(subject[:tracked_fields]).to eq [] }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field) }
        end

        context 'with [:my_dynamic_field]' do
          let(:value) { [:my_dynamic_field] }
          it { expect(subject[:on]).to eq %w(my_dynamic_field) }
          it { expect(subject[:tracked_fields]).to eq [] }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field) }
        end

        context 'with [:all, :my_dynamic_field]' do
          let(:value) { [:all, :my_dynamic_field] }
          it { expect(subject[:on]).to eq %w(fields my_dynamic_field) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field) }
        end

        context 'with [:fields, :my_dynamic_field]' do
          let(:value) { [:fields, :my_dynamic_field] }
          it { expect(subject[:on]).to eq %w(fields my_dynamic_field) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field) }
        end

        context 'with [:foo, :bar, :my_dynamic_field]' do
          let(:value) { [:foo, :bar, :my_dynamic_field] }
          it { expect(subject[:on]).to eq %w(foo bar my_dynamic_field) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field) }
        end

        context 'with [:my_dynamic_field, :my_options_embed_many_models]' do
          let(:value) { [:my_dynamic_field, :my_options_embed_many_models] }
          it { expect(subject[:on]).to eq %w(my_dynamic_field my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq [] }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field my_options_embed_many_models) }
        end

        context 'with [:all, :my_dynamic_field, :my_options_embed_many_models]' do
          let(:value) { [:all, :my_dynamic_field, :my_options_embed_many_models] }
          it { expect(subject[:on]).to eq %w(fields my_dynamic_field my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field my_options_embed_many_models) }
        end

        context 'with [:foo, :some_dynamic_field, :my_options_embed_many_models]' do
          let(:value) { [:foo, :my_dynamic_field, :my_options_embed_many_models] }
          it { expect(subject[:on]).to eq %w(foo my_dynamic_field my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq %w(foo) }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field my_options_embed_many_models) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field my_options_embed_many_models) }
        end
      end

      describe ':except' do
        let(:options) { { except: value } }

        context 'with :foo' do
          let(:value) { :foo }
          it { expect(subject[:on]).to eq %w(fields) }
          it { expect(subject[:tracked_fields]).to eq %w(bar) }
          it { expect(subject[:tracked_dynamic]).to eq [] }
        end

        context 'with [:foo]' do
          let(:value) { [:foo] }
          it { expect(subject[:on]).to eq %w(fields) }
          it { expect(subject[:tracked_fields]).to eq %w(bar) }
          it { expect(subject[:tracked_dynamic]).to eq [] }
        end

        context 'with [:foo, :bar]' do
          let(:value) { [:foo, :bar] }
          it { expect(subject[:on]).to eq %w(fields) }
          it { expect(subject[:tracked_fields]).to eq [] }
          it { expect(subject[:tracked_dynamic]).to eq [] }
        end

        context 'with :my_options_embed_many_models' do
          let(:value) { :my_options_embed_many_models }
          let(:options) { { on: [:foo, :my_options_embed_many_models], except: value } }
          it { expect(subject[:on]).to eq %w(foo my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq %w(foo) }
          it { expect(subject[:tracked_relations]).to eq [] }
          it { expect(subject[:tracked_dynamic]).to eq [] }
        end

        context 'with [:my_options_embed_many_models]' do
          let(:value) { [:my_options_embed_many_models] }
          let(:options) { { on: [:foo, :my_options_embed_many_models], except: value } }
          it { expect(subject[:on]).to eq %w(foo my_options_embed_many_models) }
          it { expect(subject[:tracked_fields]).to eq %w(foo) }
          it { expect(subject[:tracked_relations]).to eq [] }
          it { expect(subject[:tracked_dynamic]).to eq [] }
        end

        context 'with [:foo, :my_options_embed_many_models]' do
          let(:value) { [:foo, :my_options_embed_many_models] }
          let(:options) { { on: [:all, :my_options_embed_many_models, :my_options_embed_many_two_models], except: value } }
          it { expect(subject[:on]).to eq %w(fields my_options_embed_many_models emtwo) }
          it { expect(subject[:tracked_fields]).to eq %w(bar) }
          it { expect(subject[:tracked_relations]).to eq %w(emtwo) }
          it { expect(subject[:tracked_dynamic]).to eq %w(emtwo) }
        end

        context 'with [:foo, :my_dynamic_field]' do
          let(:value) { [:foo, :my_dynamic_field] }
          let(:options) { { on: [:all, :my_dynamic_field, :my_dynamic_field_two], except: value } }
          it { expect(subject[:on]).to eq %w(fields my_dynamic_field my_dynamic_field_two) }
          it { expect(subject[:tracked_fields]).to eq %w(bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field_two) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field_two) }
        end

        context 'with [:my_dynamic_field, :my_options_embed_many_models]' do
          let(:value) { [:my_dynamic_field, :my_options_embed_many_models] }
          let(:options) { { on: [:all, :my_dynamic_field, :my_dynamic_field_two, :my_options_embed_many_models, :my_options_embed_many_two_models], except: value } }
          it { expect(subject[:on]).to eq %w(fields my_dynamic_field my_dynamic_field_two my_options_embed_many_models emtwo) }
          it { expect(subject[:tracked_fields]).to eq %w(foo bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field_two emtwo) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field_two emtwo) }
        end

        context 'with [:foo, :my_dynamic_field, :my_options_embed_many_models]' do
          let(:value) { [:foo, :my_dynamic_field, :my_options_embed_many_models] }
          let(:options) { { on: [:all, :my_dynamic_field, :my_dynamic_field_two, :my_options_embed_many_models, :my_options_embed_many_two_models], except: value } }
          it { expect(subject[:on]).to eq %w(fields my_dynamic_field my_dynamic_field_two my_options_embed_many_models emtwo) }
          it { expect(subject[:tracked_fields]).to eq %w(bar) }
          it { expect(subject[:tracked_relations]).to eq %w(my_dynamic_field_two emtwo) }
          it { expect(subject[:tracked_dynamic]).to eq %w(my_dynamic_field_two emtwo) }
        end
      end

      describe ':modifier_field' do
        let(:options) { { modifier_field: :my_modifier_field } }
        it { expect(subject[:modifier_field]).to eq :my_modifier_field }
      end

      describe ':version_field' do
        let(:options) { { version_field: :my_version_field } }
        it { expect(subject[:version_field]).to eq :my_version_field }
      end

      describe ':changes_method' do
        let(:options) { { changes_method: :my_changes_method } }
        it { expect(subject[:changes_method]).to eq :my_changes_method }
      end

      describe ':scope' do
        let(:options) { { scope: :my_scope } }
        it { expect(subject[:scope]).to eq :my_scope }
      end

      describe ':track_create' do
        let(:options) { { track_create: true } }
        it { expect(subject[:track_create]).to be true }
      end

      describe ':track_update' do
        let(:options) { { track_update: false } }
        it { expect(subject[:track_update]).to be false }
      end

      describe ':track_destroy' do
        let(:options) { { track_destroy: true } }
        it { expect(subject[:track_destroy]).to be true }
      end

      describe '#remove_reserved_fields' do
        let(:options) { { on: [:_id, :_type, :foo, :version, :modifier_id] } }
        it { expect(subject[:tracked_fields]).to eq %w(foo) }
        it { expect(subject[:tracked_relations]).to eq [] }
        it { expect(subject[:tracked_dynamic]).to eq [] }
      end
    end
  end

  after :all do
    Object.send(:remove_const, :MyOptionsModel)
    Object.send(:remove_const, :MyOptionsEmbedManyModel)
    Object.send(:remove_const, :MyOptionsEmbedManyTwoModel)
  end
end
