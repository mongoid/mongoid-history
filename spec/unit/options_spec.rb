require 'spec_helper'

describe Mongoid::History::Options do
  before :each do
    class ModelOne
      include Mongoid::Document
      include Mongoid::History::Trackable

      store_in collection: :model_ones

      field :foo
      field :b, as: :bar

      if Mongoid::Compatibility::Version.mongoid7_or_newer?
        embeds_one :emb_one
        embeds_one :emb_two, store_as: :emtw
        embeds_many :emb_threes
        embeds_many :emb_fours, store_as: :emfs
      else
        embeds_one :emb_one, inverse_class_name: 'EmbOne'
        embeds_one :emb_two, store_as: :emtw, inverse_class_name: 'EmbTwo'
        embeds_many :emb_threes, inverse_class_name: 'EmbThree'
        embeds_many :emb_fours, store_as: :emfs, inverse_class_name: 'EmbFour'
      end

      track_history
    end

    class EmbOne
      include Mongoid::Document

      field :f_em_foo
      field :fmb, as: :f_em_bar

      embedded_in :model_one
    end

    class EmbTwo
      include Mongoid::Document

      field :f_em_baz
      embedded_in :model_one
    end

    class EmbThree
      include Mongoid::Document

      field :f_em_foo
      field :fmb, as: :f_em_bar

      embedded_in :model_one
    end

    class EmbFour
      include Mongoid::Document

      field :f_em_baz
      embedded_in :model_one
    end
  end

  after :each do
    Object.send(:remove_const, :ModelOne)
    Object.send(:remove_const, :EmbOne)
    Object.send(:remove_const, :EmbTwo)
    Object.send(:remove_const, :EmbThree)
    Object.send(:remove_const, :EmbFour)
  end

  let(:options) { {} }
  let(:service) { described_class.new(ModelOne, options) }

  subject { service }

  it { is_expected.to respond_to :trackable }
  it { is_expected.to respond_to :options }

  describe '#initialize' do
    it { expect(service.trackable).to eq ModelOne }
  end

  describe '#scope' do
    it { expect(service.scope).to eq :model_one }
  end

  describe '#parse' do
    it 'does not mutate the original options' do
      original_options = service.options.dup
      service.prepared
      expect(service.options).to eq original_options
    end

    describe '#default_options' do
      let(:expected_options) do
        {
          on: :all,
          except: %i[created_at updated_at],
          tracker_class_name: nil,
          modifier_field: :modifier,
          version_field: :version,
          changes_method: :changes,
          scope: :model_one,
          track_create: true,
          track_update: true,
          track_destroy: true,
          track_blank_changes: false,
          format: nil
        }
      end
      it { expect(service.send(:default_options)).to eq expected_options }
    end

    describe '#prepare_skipped_fields' do
      let(:options) { { except: value } }
      subject { service.prepared }

      context 'with field' do
        let(:value) { :foo }
        it { expect(subject[:except]).to eq %w[foo] }
      end

      context 'with array of fields' do
        let(:value) { %i[foo] }
        it { expect(subject[:except]).to eq %w[foo] }
      end

      context 'with field alias' do
        let(:value) { %i[foo bar] }
        it { expect(subject[:except]).to eq %w[foo b] }
      end

      context 'with duplicate values' do
        let(:value) { %i[foo bar b] }
        it { expect(subject[:except]).to eq %w[foo b] }
      end

      context 'with blank values' do
        let(:value) { %i[foo] | [nil] }
        it { expect(subject[:except]).to eq %w[foo] }
      end
    end

    describe '#prepare_formatted_fields' do
      let(:options) { { format: value } }
      subject { service.prepared }

      context 'with non-hash' do
        let(:value) { :foo }
        it { expect(subject[:format]).to eq({}) }
      end

      context 'with a field format' do
        let(:value) { { foo: '&&&' } }
        it { expect(subject[:format]).to include 'foo' => '&&&' }
      end

      context 'with nested format' do
        let(:value) { { emb_one: { f_em_foo: '***' } } }
        it { expect(subject[:format]).to include 'emb_one' => { 'f_em_foo' => '***' } }
      end
    end

    describe '#parse_tracked_fields_and_relations' do
      context 'when options not passed' do
        let(:expected_options) do
          {
            on: %i[foo b],
            except: %w[created_at updated_at],
            tracker_class_name: nil,
            modifier_field: :modifier,
            version_field: :version,
            changes_method: :changes,
            scope: :model_one,
            track_create: true,
            track_update: true,
            track_destroy: true,
            track_blank_changes: false,
            fields: %w[foo b],
            dynamic: [],
            relations: { embeds_one: {}, embeds_many: {} },
            format: {}
          }
        end
        it { expect(service.prepared).to eq expected_options }
      end

      context 'when options passed' do
        subject { service.prepared }

        describe '@options' do
          let(:options) { { on: value } }

          context 'with field' do
            let(:value) { :foo }
            it { expect(subject[:on]).to eq %i[foo] }
            it { expect(subject[:fields]).to eq %w[foo] }
          end

          context 'with array of fields' do
            let(:value) { %i[foo] }
            it { expect(subject[:on]).to eq %i[foo] }
            it { expect(subject[:fields]).to eq %w[foo] }
          end

          context 'with embeds_one relation attributes' do
            let(:value) { { emb_one: %i[f_em_foo] } }
            it { expect(subject[:on]).to eq [[:emb_one, %i[f_em_foo]]] }
          end

          context 'with fields and embeds_one relation attributes' do
            let(:value) { [:foo, emb_one: %i[f_em_foo]] }
            it { expect(subject[:on]).to eq [:foo, emb_one: %i[f_em_foo]] }
          end

          context 'with :all' do
            let(:value) { :all }
            it { expect(subject[:on]).to eq %i[foo b] }
          end

          context 'with :fields' do
            let(:value) { :fields }
            it { expect(subject[:on]).to eq %i[foo b] }
          end

          describe '#categorize_tracked_option' do
            context 'with skipped field' do
              let(:options) { { on: %i[foo bar], except: :foo } }
              it { expect(subject[:fields]).to eq %w[b] }
            end

            context 'with skipped embeds_one relation' do
              let(:options) { { on: %i[fields emb_one emb_two], except: :emb_one } }
              it { expect(subject[:relations][:embeds_one]).to eq('emtw' => %w[_id f_em_baz]) }
            end

            context 'with skipped embeds_many relation' do
              let(:options) { { on: %i[fields emb_threes emb_fours], except: :emb_threes } }
              it { expect(subject[:relations][:embeds_many]).to eq('emfs' => %w[_id f_em_baz]) }
            end

            context 'with reserved field' do
              let(:options) { { on: %i[_id _type foo deleted_at] } }
              it { expect(subject[:fields]).to eq %w[foo] }
            end

            context 'when embeds_one attribute passed' do
              let(:options) { { on: { emb_one: :f_em_foo } } }
              it { expect(subject[:relations][:embeds_one]).to eq('emb_one' => %w[_id f_em_foo]) }
            end

            context 'when embeds_one attributes array passed' do
              let(:options) { { on: { emb_one: %i[f_em_foo] } } }
              it { expect(subject[:relations][:embeds_one]).to eq('emb_one' => %w[_id f_em_foo]) }
            end

            context 'when embeds_many attribute passed' do
              let(:options) { { on: { emb_threes: :f_em_foo } } }
              it { expect(subject[:relations][:embeds_many]).to eq('emb_threes' => %w[_id f_em_foo]) }
            end

            context 'when embeds_many attributes array passed' do
              let(:options) { { on: { emb_threes: %i[f_em_foo] } } }
              it { expect(subject[:relations][:embeds_many]).to eq('emb_threes' => %w[_id f_em_foo]) }
            end

            context 'when embeds_one attributes not passed' do
              let(:options) { { on: :emb_one } }
              it { expect(subject[:relations][:embeds_one]).to eq('emb_one' => %w[_id f_em_foo fmb]) }
            end

            context 'when embeds_many attributes not passed' do
              let(:options) { { on: :emb_threes } }
              it { expect(subject[:relations][:embeds_many]).to eq('emb_threes' => %w[_id f_em_foo fmb]) }
            end

            context 'when embeds_one attribute alias passed' do
              let(:options) { { on: { emb_one: %i[f_em_bar] } } }
              it { expect(subject[:relations][:embeds_one]).to eq('emb_one' => %w[_id fmb]) }
            end

            context 'when embeds_many attribute alias passed' do
              let(:options) { { on: { emb_threes: %i[f_em_bar] } } }
              it { expect(subject[:relations][:embeds_many]).to eq('emb_threes' => %w[_id fmb]) }
            end

            context 'with fields, and multiple embeds_one, and embeds_many relations' do
              let(:options) { { on: [:foo, :bar, :emb_two, { emb_threes: %i[f_em_foo f_em_bar], emb_fours: :f_em_baz }] } }
              it 'should categorize fields and associations correctly' do
                expect(subject[:fields]).to eq(%w[foo b])
                expect(subject[:relations][:embeds_one]).to eq('emtw' => %w[_id f_em_baz])
                expect(subject[:relations][:embeds_many]).to eq('emb_threes' => %w[_id f_em_foo fmb], 'emfs' => %w[_id f_em_baz])
              end
            end

            context 'with field alias' do
              let(:options) { { on: :bar } }
              it { expect(subject[:fields]).to eq %w[b] }
            end

            context 'with dynamic field name' do
              let(:options) { { on: :my_field } }
              it { expect(subject[:dynamic]).to eq %w[my_field] }
            end

            context 'with relations' do
              let(:options) { { on: :embedded_relations } }
              it do
                expect(subject[:relations]).to eq(
                  embeds_many: { 'emb_threes' => %w[_id f_em_foo fmb],
                                 'emfs' => %w[_id f_em_baz] },
                  embeds_one: { 'emb_one' => %w[_id f_em_foo fmb],
                                'emtw' => %w[_id f_em_baz] }
                )
              end
            end
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

        describe ':paranoia_field' do
          let(:options) { { paranoia_field: :my_paranoia_field } }
          it { expect(subject[:paranoia_field]).to eq :my_paranoia_field }
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
          let(:options) { { on: %i[_id _type foo version modifier_id] } }
          it { expect(subject[:fields]).to eq %w[foo] }
          it { expect(subject[:dynamic]).to eq [] }
        end
      end
    end
  end
end
