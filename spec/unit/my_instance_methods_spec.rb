require 'spec_helper'

describe Mongoid::History::Trackable do
  describe 'MyInstanceMethods' do
    before :each do
      class ModelOne
        include Mongoid::Document
        include Mongoid::History::Trackable

        store_in collection: :model_ones

        field :foo
        field :b, as: :bar

        if Mongoid::Compatibility::Version.mongoid7_or_newer?
          embeds_one :emb_one
          embeds_one :emb_two, store_as: :emt
          embeds_many :emb_threes
          embeds_many :emb_fours, store_as: :emfs
        else
          embeds_one :emb_one, inverse_class_name: 'EmbOne'
          embeds_one :emb_two, store_as: :emt, inverse_class_name: 'EmbTwo'
          embeds_many :emb_threes, inverse_class_name: 'EmbThree'
          embeds_many :emb_fours, store_as: :emfs, inverse_class_name: 'EmbFour'
        end
      end

      class EmbOne
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :f_em_foo
        field :fmb, as: :f_em_bar

        embedded_in :model_one
      end

      class EmbTwo
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :baz
        embedded_in :model_one
      end

      class EmbThree
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :f_em_foo
        field :fmb, as: :f_em_bar

        embedded_in :model_one
      end

      class EmbFour
        include Mongoid::Document
        include Mongoid::History::Trackable

        field :baz
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

    let(:bson_class) { defined?(BSON::ObjectId) ? BSON::ObjectId : Moped::BSON::ObjectId }

    let(:emb_one) { EmbOne.new(f_em_foo: 'Foo', f_em_bar: 'Bar') }
    let(:emb_threes) { [EmbThree.new(f_em_foo: 'Foo', f_em_bar: 'Bar')] }
    let(:model_one) { ModelOne.new(foo: 'Foo', bar: 'Bar', emb_one: emb_one, emb_threes: emb_threes) }

    describe '#modified_attributes_for_create' do
      before :each do
        ModelOne.track_history modifier_field_optional: true, on: %i[foo emb_one emb_threes]
      end

      subject { model_one.send(:modified_attributes_for_create) }

      context 'with tracked embeds_one object' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: { emb_one: :f_em_foo })
        end
        it 'should include tracked attributes only' do
          expect(subject['emb_one'][0]).to be_nil

          expect(subject['emb_one'][1].keys.size).to eq 2
          expect(subject['emb_one'][1]['_id']).to eq emb_one._id
          expect(subject['emb_one'][1]['f_em_foo']).to eq 'Foo'
        end
      end

      context 'with untracked embeds_one object' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :fields)
        end
        it 'should not include embeds_one attributes' do
          expect(subject['emb_one']).to be_nil
        end
      end

      context 'with tracked embeds_many objects' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: { emb_threes: :f_em_foo })
        end
        it 'should include tracked attributes only' do
          expect(subject['emb_threes'][0]).to be_nil

          expect(subject['emb_threes'][1][0].keys.count).to eq 2
          expect(subject['emb_threes'][1][0]['_id']).to eq emb_threes.first._id
          expect(subject['emb_threes'][1][0]['f_em_foo']).to eq 'Foo'
        end
      end

      context 'with untracked embeds_many objects' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :fields)
        end
        it 'should include not tracked embeds_many attributes' do
          expect(subject['emb_threes']).to be_nil
        end
      end

      context 'when embeds_one object blank' do
        let(:emb_one) { nil }

        it 'should not include embeds_one model key' do
          expect(subject.keys).to_not include 'emb_one'
        end
      end

      describe 'embeds_one' do
        before :each do
          class Mail
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :mails
            field :provider

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :mail_subject
            else
              embeds_one :mail_subject, inverse_class_name: 'MailSubject'
            end

            track_history on: :mail_subject
          end

          class MailSubject
            include Mongoid::Document

            field :content
            embedded_in :mail
          end
        end

        after :each do
          Object.send(:remove_const, :MailSubject)
          Object.send(:remove_const, :Mail)
        end

        let(:mail) { Mail.new(mail_subject: mail_subject) }
        let(:mail_subject) { nil }
        subject { mail.send(:modified_attributes_for_create)['mail_subject'] }

        context 'when obj not built' do
          it { is_expected.to be_nil }
        end

        context 'when obj does not respond to paranoia_field' do
          let(:mail_subject) { MailSubject.new(content: 'Content') }
          it { is_expected.to eq [nil, { '_id' => mail_subject._id, 'content' => 'Content' }] }
        end

        context 'when obj not soft-deleted' do
          before :each do
            allow(mail_subject).to receive(:deleted_at) { nil }
          end
          let(:mail_subject) { MailSubject.new(content: 'Content') }
          it { is_expected.to eq [nil, { '_id' => mail_subject._id, 'content' => 'Content' }] }
        end

        context 'when obj soft-deleted' do
          before :each do
            allow(mail_subject).to receive(:deleted_at) { Time.now }
          end
          let(:mail_subject) { MailSubject.new(content: 'Content') }
          it { is_expected.to be_nil }
        end
      end

      describe 'paranoia' do
        before :each do
          class ModelParanoia
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :model_paranoias

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_many :emb_para_ones
            else
              embeds_many :emb_para_ones, inverse_class_name: 'EmbParaOne'
            end
          end

          class EmbParaOne
            include Mongoid::Document

            field :em_foo
            field :deleted_at

            embedded_in :model_paranoia
          end
        end

        after :each do
          Object.send(:remove_const, :ModelParanoia)
          Object.send(:remove_const, :EmbParaOne)
        end

        let(:emb_para_one) { EmbParaOne.new(em_foo: 'Em-Foo') }
        let(:model_paranoia) { ModelParanoia.new(emb_para_ones: [emb_para_one]) }

        context 'when does not respond to paranoia_field' do
          before :each do
            ModelParanoia.track_history(on: :emb_para_ones)
          end

          subject { model_paranoia.send(:modified_attributes_for_create) }

          it 'should include tracked embeds_many objects attributes' do
            expect(subject['emb_para_ones'][0]).to be_nil
            expect(subject['emb_para_ones'][1].size).to eq 1
            expect(subject['emb_para_ones'][1][0]['_id']).to be_a bson_class
            expect(subject['emb_para_ones'][1][0]['em_foo']).to eq 'Em-Foo'
          end
        end

        context 'when responds to paranoia_field' do
          before :each do
            ModelParanoia.track_history(on: :emb_para_ones)
            allow(emb_para_one).to receive(:deleted_at) { Time.now }
            allow(emb_para_one_2).to receive(:deleted_at) { nil }
          end

          let(:model_paranoia) { ModelParanoia.new(emb_para_ones: [emb_para_one, emb_para_one_2]) }
          let(:emb_para_one) { EmbParaOne.new(em_foo: 'Em-Foo') }
          let(:emb_para_one_2) { EmbParaOne.new(em_foo: 'Em-Foo-2') }

          subject { model_paranoia.send(:modified_attributes_for_create) }

          it 'should not include deleted objects attributes' do
            expect(subject['emb_para_ones'][0]).to be_nil
            expect(subject['emb_para_ones'][1]).to eq [{ '_id' => emb_para_one_2._id, 'em_foo' => 'Em-Foo-2' }]
          end
        end
      end
    end

    describe '#modified_attributes_for_update' do
      before :each do
        model_one.save!
        allow(ModelOne).to receive(:dynamic_enabled?) { false }
        allow(model_one).to receive(:changes) { changes }
      end
      let(:changes) { {} }
      subject { model_one.send(:modified_attributes_for_update) }

      context 'when embeds_one attributes passed in options' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: { emb_one: :f_em_foo })
        end
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }, { 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }] } }
        it { expect(subject['emb_one'][0]).to eq('f_em_foo' => 'Foo') }
        it { expect(subject['emb_one'][1]).to eq('f_em_foo' => 'Foo-new') }
      end

      context 'when embeds_one relation passed in options' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :emb_one)
        end
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }, { 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }] } }
        it { expect(subject['emb_one'][0]).to eq('f_em_foo' => 'Foo', 'fmb' => 'Bar') }
        it { expect(subject['emb_one'][1]).to eq('f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new') }
      end

      context 'when embeds_one relation not tracked' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :fields)
        end
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo' }, { 'f_em_foo' => 'Foo-new' }] } }
        it { expect(subject['emb_one']).to be_nil }
      end

      context 'when embeds_many attributes passed in options' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: { emb_threes: :f_em_foo })
        end
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] } }
        it { expect(subject['emb_threes']).to eq [[{ 'f_em_foo' => 'Foo' }], [{ 'f_em_foo' => 'Foo-new' }]] }
      end

      context 'when embeds_many relation passed in options' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :emb_threes)
        end
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] } }
        it { expect(subject['emb_threes']).to eq [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] }
      end

      context 'when embeds_many relation not tracked' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :fields)
        end
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo' }], [{ 'f_em_foo' => 'Foo-new' }]] } }
        it { expect(subject['emb_threes']).to be_nil }
      end

      context 'when field tracked' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :foo)
        end
        let(:changes) { { 'foo' => ['Foo', 'Foo-new'], 'b' => ['Bar', 'Bar-new'] } }
        it { is_expected.to eq('foo' => ['Foo', 'Foo-new']) }
      end

      context 'when field not tracked' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: [])
        end
        let(:changes) { { 'foo' => ['Foo', 'Foo-new'] } }
        it { is_expected.to eq({}) }
      end

      describe 'embeds_one' do
        before :each do
          class Email
            include Mongoid::Document
            include Mongoid::History::Trackable

            store_in collection: :emails
            field :provider

            if Mongoid::Compatibility::Version.mongoid7_or_newer?
              embeds_one :email_subject
            else
              embeds_one :email_subject, inverse_class_name: 'EmailSubject'
            end

            track_history on: :email_subject
          end

          class EmailSubject
            include Mongoid::Document
            include Mongoid::History::Trackable

            field :content
            embedded_in :email_subject
          end
        end

        after :each do
          Object.send(:remove_const, :EmailSubject)
          Object.send(:remove_const, :Email)
        end

        before :each do
          allow(Email).to receive(:dynamic_enabled?) { false }
          allow(email).to receive(:changes) { changes }
        end

        let(:email) { Email.new }
        let(:changes) { {} }
        subject { email.send(:modified_attributes_for_update)['email_subject'] }

        context 'when paranoia_field not present' do
          let(:changes) { { 'email_subject' => [{ 'content' => 'Content' }, { 'content' => 'Content-new' }] } }
          it { is_expected.to eq [{ 'content' => 'Content' }, { 'content' => 'Content-new' }] }
        end

        context 'when older soft-deleted' do
          let(:changes) { { 'email_subject' => [{ 'content' => 'Content', 'deleted_at' => Time.now }, { 'content' => 'Content-new' }] } }
          it { is_expected.to eq [{}, { 'content' => 'Content-new' }] }
        end

        context 'when new soft-deleted' do
          let(:changes) { { 'email_subject' => [{ 'content' => 'Content' }, { 'content' => 'Content-new', 'deleted_at' => Time.now }] } }
          it { is_expected.to eq [{ 'content' => 'Content' }, {}] }
        end

        context 'when not soft-deleted' do
          let(:changes) do
            { 'email_subject' => [{ 'content' => 'Content', 'deleted_at' => nil }, { 'content' => 'Content-new', 'deleted_at' => nil }] }
          end
          it { is_expected.to eq [{ 'content' => 'Content' }, { 'content' => 'Content-new' }] }
        end
      end

      describe 'paranoia_field' do
        context 'when embeds_one has alias' do
          before :each do
            class ModelTwo
              include Mongoid::Document
              include Mongoid::History::Trackable

              store_in collection: :model_twos

              if Mongoid::Compatibility::Version.mongoid7_or_newer?
                embeds_one :emb_two_one
              else
                embeds_one :emb_two_one, inverse_class_name: 'EmbTwoOne'
              end

              track_history on: :emb_two_one
            end

            class EmbTwoOne
              include Mongoid::Document
              include Mongoid::History::Trackable

              field :foo
              field :cncl, as: :cancelled_at

              embedded_in :model_two

              history_settings paranoia_field: :cancelled_at
            end
          end

          after :each do
            Object.send(:remove_const, :ModelTwo)
            Object.send(:remove_const, :EmbTwoOne)
          end

          before :each do
            allow(ModelTwo).to receive(:dynamic_enabled?) { false }
            allow(model_two_obj).to receive(:changes) { changes }
          end

          let(:model_two_obj) { ModelTwo.new }
          let(:changes) { { 'emb_two_one' => [{ 'foo' => 'Foo', 'cncl' => Time.now }, { 'foo' => 'Foo-new' }] } }

          subject { model_two_obj.send(:modified_attributes_for_update)['emb_two_one'] }
          it { is_expected.to eq [{}, { 'foo' => 'Foo-new' }] }
        end

        context 'when embeds_many has alias' do
          before :each do
            class ModelTwo
              include Mongoid::Document
              include Mongoid::History::Trackable

              store_in collection: :model_twos

              if Mongoid::Compatibility::Version.mongoid7_or_newer?
                embeds_many :emb_two_ones
              else
                embeds_many :emb_two_ones, inverse_class_name: 'EmbTwoOne'
              end

              track_history on: :emb_two_ones
            end

            class EmbTwoOne
              include Mongoid::Document
              include Mongoid::History::Trackable

              field :foo
              field :cncl, as: :cancelled_at

              embedded_in :model_two

              history_settings paranoia_field: :cancelled_at
            end
          end

          after :each do
            Object.send(:remove_const, :ModelTwo)
            Object.send(:remove_const, :EmbTwoOne)
          end

          before :each do
            allow(ModelTwo).to receive(:dynamic_enabled?) { false }
            allow(model_two_obj).to receive(:changes) { changes }
          end

          let(:model_two_obj) { ModelTwo.new }
          let(:changes) { { 'emb_two_ones' => [[{ 'foo' => 'Foo', 'cncl' => Time.now }], [{ 'foo' => 'Foo-new' }]] } }
          subject { model_two_obj.send(:modified_attributes_for_update)['emb_two_ones'] }
          it { is_expected.to eq [[], [{ 'foo' => 'Foo-new' }]] }
        end
      end
    end

    describe '#modified_attributes_for_destroy' do
      before :each do
        allow(ModelOne).to receive(:dynamic_enabled?) { false }
        model_one.save!
      end
      subject { model_one.send(:modified_attributes_for_destroy) }

      context 'with tracked embeds_one object' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: { emb_one: :f_em_foo })
        end
        it 'should include tracked attributes only' do
          expect(subject['emb_one'][0].keys.size).to eq 2
          expect(subject['emb_one'][0]['_id']).to eq emb_one._id
          expect(subject['emb_one'][0]['f_em_foo']).to eq 'Foo'

          expect(subject['emb_one'][1]).to be_nil
        end
      end

      context 'with untracked embeds_one object' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :fields)
        end
        it 'should not include embeds_one attributes' do
          expect(subject['emb_one']).to be_nil
        end
      end

      context 'with tracked embeds_many objects' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: { emb_threes: :f_em_foo })
        end
        it 'should include tracked attributes only' do
          expect(subject['emb_threes'][0][0].keys.count).to eq 2
          expect(subject['emb_threes'][0][0]['_id']).to eq emb_threes.first._id
          expect(subject['emb_threes'][0][0]['f_em_foo']).to eq 'Foo'

          expect(subject['emb_threes'][1]).to be_nil
        end
      end

      context 'with untracked embeds_many objects' do
        before :each do
          ModelOne.track_history(modifier_field_optional: true, on: :fields)
        end
        it 'should include not tracked embeds_many attributes' do
          expect(subject['emb_threes']).to be_nil
        end
      end
    end
  end
end
