require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Model
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user, inverse_of: :models
      has_and_belongs_to_many :external_users, class_name: 'User', inverse_of: :external_models

      track_history on: %i[name user external_user_ids], # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    modifier_field_inverse_of: nil, # no inverse modifier relationship
                    version_field: :version, # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: false,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false    # track document destruction, default is false
    end

    class User
      include Mongoid::Document
      has_many :models, dependent: :destroy, inverse_of: :user
      has_and_belongs_to_many :external_model, class_name: 'Model', inverse_of: :external_users
    end
  end

  it 'should be possible to undo when having multiple relations to modifier class' do
    user = User.new
    user.save!

    model = Model.new
    model.name = 'Foo'
    model.user = user
    model.modifier = user
    model.save!

    model.name = 'Bar'
    model.save!

    model.undo! user
    expect(model.name).to eq('Foo')

    model.redo! user, 1
    expect(model.name).to eq('Bar')
  end

  it 'should track foreign key relations' do
    expect(Model.tracked_field?(:external_user_ids)).to be true
    expect(Model.tracked_field?(:user)).to be true
    expect(Model.tracked_field?(:user_id)).to be true
  end
end
