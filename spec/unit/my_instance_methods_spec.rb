require 'spec_helper'

describe Mongoid::History::Trackable do
  describe 'MyInstanceMethods' do
    before :all do
      ModelOne = Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        store_in collection: :model_ones
        field :foo
        field :b, as: :bar
        embeds_one :emb_one, inverse_class_name: 'EmbOne'
        embeds_one :emb_two, store_as: :emt, inverse_class_name: 'EmbTwo'
        embeds_many :emb_threes, inverse_class_name: 'EmbThree'
        embeds_many :emb_fours, store_as: :emfs, inverse_class_name: 'EmbFour'
      end

      EmbOne = Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        field :f_em_foo
        field :fmb, as: :f_em_bar
        embedded_in :model_one
      end

      EmbTwo = Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        field :baz
        embedded_in :model_one
      end

      EmbThree = Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        field :f_em_foo
        field :fmb, as: :f_em_bar
        embedded_in :model_one
      end

      EmbFour = Class.new do
        include Mongoid::Document
        include Mongoid::History::Trackable
        field :baz
        embedded_in :model_one
      end

      ModelOne.track_history(on: %i(foo emb_one emb_threes))
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }

    let(:bson_class) { defined?(BSON::ObjectId) ? BSON::ObjectId : Moped::BSON::ObjectId }

    let(:emb_one) { EmbOne.new(f_em_foo: 'Foo', f_em_bar: 'Bar') }
    let(:emb_threes) { [EmbThree.new(f_em_foo: 'Foo', f_em_bar: 'Bar')] }
    let(:model_one) do
      ModelOne.new(foo: 'Foo',
                   bar: 'Bar',
                   emb_one: emb_one,
                   emb_threes: emb_threes)
    end

    describe '#modified_attributes_for_create' do
      before(:each) { ModelOne.clear_trackable_memoization }
      subject { model_one.send(:modified_attributes_for_create) }

      context 'with tracked embeds_one object' do
        before(:each) { ModelOne.track_history(on: { emb_one: :f_em_foo }) }
        it 'should include tracked attributes only' do
          expect(subject['emb_one'][0]).to be_nil

          expect(subject['emb_one'][1].keys.size).to eq 2
          expect(subject['emb_one'][1]['_id']).to eq emb_one._id
          expect(subject['emb_one'][1]['f_em_foo']).to eq 'Foo'
        end
      end

      context 'with untracked embeds_one object' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it 'should not include embeds_one attributes' do
          expect(subject['emb_one']).to be_nil
        end
      end

      context 'with tracked embeds_many objects' do
        before(:each) { ModelOne.track_history(on: { emb_threes: :f_em_foo }) }
        it 'should include tracked attributes only' do
          expect(subject['emb_threes'][0]).to be_nil

          expect(subject['emb_threes'][1][0].keys.count).to eq 2
          expect(subject['emb_threes'][1][0]['_id']).to eq emb_threes.first._id
          expect(subject['emb_threes'][1][0]['f_em_foo']).to eq 'Foo'
        end
      end

      context 'with untracked embeds_many objects' do
        before(:each) { ModelOne.track_history(on: :fields) }
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
        before(:all) do
          Mail = Class.new do
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :mails
            field :provider
            embeds_one :mail_subject, inverse_class_name: 'MailSubject'
          end

          MailSubject = Class.new do
            include Mongoid::Document
            field :content
            embedded_in :mail
          end
        end

        before(:each) do
          Mail.instance_variable_set(:@history_trackable_options, nil)
          Mail.track_history(on: :mail_subject)
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
          before(:each) { allow(mail_subject).to receive(:deleted_at) { nil } }
          let(:mail_subject) { MailSubject.new(content: 'Content') }
          it { is_expected.to eq [nil, { '_id' => mail_subject._id, 'content' => 'Content' }] }
        end

        context 'when obj soft-deleted' do
          before(:each) { allow(mail_subject).to receive(:deleted_at) { Time.now } }
          let(:mail_subject) { MailSubject.new(content: 'Content') }
          it { is_expected.to be_nil }
        end

        after(:all) do
          Object.send(:remove_const, :MailSubject)
          Object.send(:remove_const, :Mail)
        end
      end

      describe 'paranoia' do
        before(:all) do
          ModelParanoia = Class.new do
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :model_paranoias
            embeds_many :emb_para_ones, inverse_class_name: 'EmbParaOne'
          end

          EmbParaOne = Class.new do
            include Mongoid::Document
            field :em_foo
            field :deleted_at
            embedded_in :model_paranoia
          end
        end

        let(:emb_para_one) { EmbParaOne.new(em_foo: 'Em-Foo') }
        let(:model_paranoia) { ModelParanoia.new(emb_para_ones: [emb_para_one]) }

        context 'when does not respond to paranoia_field' do
          before(:each) do
            ModelParanoia.instance_variable_set(:@history_trackable_options, nil)
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
          before(:each) do
            ModelParanoia.instance_variable_set(:@history_trackable_options, nil)
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

        after(:all) do
          Object.send(:remove_const, :ModelParanoia)
          Object.send(:remove_const, :EmbParaOne)
        end
      end
    end

    describe '#modified_attributes_for_update' do
      before(:each) do
        model_one.save!
        ModelOne.clear_trackable_memoization
        allow(ModelOne).to receive(:dynamic_enabled?) { false }
        allow(model_one).to receive(:changes) { changes }
      end
      let(:changes) { {} }
      subject { model_one.send(:modified_attributes_for_update) }

      context 'when embeds_one attributes passed in options' do
        before(:each) { ModelOne.track_history(on: { emb_one: :f_em_foo }) }
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }, { 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }] } }
        it { expect(subject['emb_one'][0]).to eq('f_em_foo' => 'Foo') }
        it { expect(subject['emb_one'][1]).to eq('f_em_foo' => 'Foo-new') }
      end

      context 'when embeds_one relation passed in options' do
        before(:each) { ModelOne.track_history(on: :emb_one) }
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }, { 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }] } }
        it { expect(subject['emb_one'][0]).to eq('f_em_foo' => 'Foo', 'fmb' => 'Bar') }
        it { expect(subject['emb_one'][1]).to eq('f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new') }
      end

      context 'when embeds_one relation not tracked' do
        before(:each) { ModelOne.track_history(on: :fields) }
        let(:changes) { { 'emb_one' => [{ 'f_em_foo' => 'Foo' }, { 'f_em_foo' => 'Foo-new' }] } }
        it { expect(subject['emb_one']).to be_nil }
      end

      context 'when embeds_many attributes passed in options' do
        before(:each) { ModelOne.track_history(on: { emb_threes: :f_em_foo }) }
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] } }
        it { expect(subject['emb_threes']).to eq [[{ 'f_em_foo' => 'Foo' }], [{ 'f_em_foo' => 'Foo-new' }]] }
      end

      context 'when embeds_many relation passed in options' do
        before(:each) { ModelOne.track_history(on: :emb_threes) }
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] } }
        it { expect(subject['emb_threes']).to eq [[{ 'f_em_foo' => 'Foo', 'fmb' => 'Bar' }], [{ 'f_em_foo' => 'Foo-new', 'fmb' => 'Bar-new' }]] }
      end

      context 'when embeds_many relation not tracked' do
        before(:each) { ModelOne.track_history(on: :fields) }
        let(:changes) { { 'emb_threes' => [[{ 'f_em_foo' => 'Foo' }], [{ 'f_em_foo' => 'Foo-new' }]] } }
        it { expect(subject['emb_threes']).to be_nil }
      end

      context 'when field tracked' do
        before(:each) { ModelOne.track_history(on: :foo) }
        let(:changes) { { 'foo' => ['Foo', 'Foo-new'], 'b' => ['Bar', 'Bar-new'] } }
        it { is_expected.to eq('foo' => ['Foo', 'Foo-new']) }
      end

      context 'when field not tracked' do
        before(:each) { ModelOne.track_history(on: []) }
        let(:changes) { { 'foo' => ['Foo', 'Foo-new'] } }
        it { is_expected.to eq({}) }
      end

      describe 'embeds_one' do
        before(:all) do
          Email = Class.new do
            include Mongoid::Document
            include Mongoid::History::Trackable
            store_in collection: :emails
            field :provider
            embeds_one :email_subject, inverse_class_name: 'EmailSubject'
          end

          EmailSubject = Class.new do
            include Mongoid::Document
            include Mongoid::History::Trackable
            field :content
            embedded_in :email_subject
          end
        end

        before(:each) do
          Email.instance_variable_set(:@history_trackable_options, nil)
          Email.track_history(on: :email_subject)
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

        after(:all) do
          Object.send(:remove_const, :EmailSubject)
          Object.send(:remove_const, :Email)
        end
      end

      describe 'paranoia_field' do
        context 'when embeds_one has alias' do
          before(:all) do
            # Here i need class name constant in trackable.rb. So, not using `let` to define classes
            ModelTwo = Class.new do
              include Mongoid::Document
              include Mongoid::History::Trackable
              store_in collection: :model_twos
              embeds_one :emb_two_one, inverse_class_name: 'EmbTwoOne'
            end

            EmbTwoOne = Class.new do
              include Mongoid::Document
              include Mongoid::History::Trackable
              field :foo
              field :cncl, as: :cancelled_at
              embedded_in :model_two
            end
          end

          before(:each) do
            ModelTwo.instance_variable_set(:@history_trackable_options, nil)
            ModelTwo.instance_variable_set(:@trackable_settings, nil)
            EmbTwoOne.instance_variable_set(:@trackable_settings, nil)

            ModelTwo.track_history on: :emb_two_one
            EmbTwoOne.history_settings paranoia_field: :cancelled_at

            allow(ModelTwo).to receive(:dynamic_enabled?) { false }
            allow(model_two_obj).to receive(:changes) { changes }
          end

          let(:model_two_obj) { ModelTwo.new }
          let(:changes) { { 'emb_two_one' => [{ 'foo' => 'Foo', 'cncl' => Time.now }, { 'foo' => 'Foo-new' }] } }
          subject { model_two_obj.send(:modified_attributes_for_update)['emb_two_one'] }
          it { is_expected.to eq [{}, { 'foo' => 'Foo-new' }] }

          after(:all) do
            Object.send(:remove_const, :ModelTwo)
            Object.send(:remove_const, :EmbTwoOne)
          end
        end

        context 'when embeds_many has alias' do
          before(:all) do
            # Here i need class name constant in trackable.rb. So, not using `let` to define classes
            ModelTwo = Class.new do
              include Mongoid::Document
              include Mongoid::History::Trackable
              store_in collection: :model_twos
              embeds_many :emb_two_ones, inverse_class_name: 'EmbTwoOne'
            end

            EmbTwoOne = Class.new do
              include Mongoid::Document
              include Mongoid::History::Trackable
              field :foo
              field :cncl, as: :cancelled_at
              embedded_in :model_two
            end
          end

          before(:each) do
            ModelTwo.instance_variable_set(:@history_trackable_options, nil)
            ModelTwo.instance_variable_set(:@trackable_settings, nil)
            EmbTwoOne.instance_variable_set(:@trackable_settings, nil)

            ModelTwo.track_history on: :emb_two_ones
            EmbTwoOne.history_settings paranoia_field: :cancelled_at

            allow(ModelTwo).to receive(:dynamic_enabled?) { false }
            allow(model_two_obj).to receive(:changes) { changes }
          end

          let(:model_two_obj) { ModelTwo.new }
          let(:changes) { { 'emb_two_ones' => [[{ 'foo' => 'Foo', 'cncl' => Time.now }], [{ 'foo' => 'Foo-new' }]] } }
          subject { model_two_obj.send(:modified_attributes_for_update)['emb_two_ones'] }
          it { is_expected.to eq [[], [{ 'foo' => 'Foo-new' }]] }

          after(:all) do
            Object.send(:remove_const, :ModelTwo)
            Object.send(:remove_const, :EmbTwoOne)
          end
        end
      end
    end

    describe '#modified_attributes_for_destroy' do
      before(:each) do
        allow(ModelOne).to receive(:dynamic_enabled?) { false }
        model_one.save!
        ModelOne.clear_trackable_memoization
      end
      subject { model_one.send(:modified_attributes_for_destroy) }

      context 'with tracked embeds_one object' do
        before(:each) { ModelOne.track_history(on: { emb_one: :f_em_foo }) }
        it 'should include tracked attributes only' do
          expect(subject['emb_one'][0].keys.size).to eq 2
          expect(subject['emb_one'][0]['_id']).to eq emb_one._id
          expect(subject['emb_one'][0]['f_em_foo']).to eq 'Foo'

          expect(subject['emb_one'][1]).to be_nil
        end
      end

      context 'with untracked embeds_one object' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it 'should not include embeds_one attributes' do
          expect(subject['emb_one']).to be_nil
        end
      end

      context 'with tracked embeds_many objects' do
        before(:each) { ModelOne.track_history(on: { emb_threes: :f_em_foo }) }
        it 'should include tracked attributes only' do
          expect(subject['emb_threes'][0][0].keys.count).to eq 2
          expect(subject['emb_threes'][0][0]['_id']).to eq emb_threes.first._id
          expect(subject['emb_threes'][0][0]['f_em_foo']).to eq 'Foo'

          expect(subject['emb_threes'][1]).to be_nil
        end
      end

      context 'with untracked embeds_many objects' do
        before(:each) { ModelOne.track_history(on: :fields) }
        it 'should include not tracked embeds_many attributes' do
          expect(subject['emb_threes']).to be_nil
        end
      end
    end

    after :all do
      Object.send(:remove_const, :ModelOne)
      Object.send(:remove_const, :EmbOne)
      Object.send(:remove_const, :EmbTwo)
      Object.send(:remove_const, :EmbThree)
      Object.send(:remove_const, :EmbFour)
    end
  end
end
