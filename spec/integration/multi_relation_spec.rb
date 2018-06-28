require 'spec_helper'

describe Mongoid::History::Tracker do
  before :each do
    class Model
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user, inverse_of: :models
      has_and_belongs_to_many :external_users, class_name: 'User', inverse_of: :external_models

      track_history on: %i[name user external_user_ids], modifier_field_inverse_of: nil
    end

    class User
      include Mongoid::Document

      has_many :models, dependent: :destroy, inverse_of: :user
      has_and_belongs_to_many :external_model, class_name: 'Model', inverse_of: :external_users
    end
  end

  after :each do
    Object.send(:remove_const, :Model)
    Object.send(:remove_const, :User)
  end

  let(:user) { User.create! }
  let(:model) { Model.create!(name: 'Foo', user: user, modifier: user) }

  it 'should be possible to undo when having multiple relations to modifier class' do
    model.update_attributes!(name: 'Bar', modifier: user)

    model.undo! user
    expect(model.name).to eq 'Foo'

    model.redo! user, 2
    expect(model.name).to eq 'Bar'
  end

  it 'should track foreign key relations' do
    expect(Model.tracked_field?(:external_user_ids)).to be true
    expect(Model.tracked_field?(:user)).to be true
    expect(Model.tracked_field?(:user_id)).to be true
  end
end
