require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class RealState
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user
      embeds_one :address, class_name: 'Contact', as: :contactable

      track_history on: :all,       # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: true,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false    # track document destruction, default is false
    end

    class Company
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      belongs_to :user
      embeds_one :address, class_name: 'Contact', as: :contactable
      embeds_one :second_address, class_name: 'Contact', as: :contactable

      track_history on: :all,       # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: true,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false   # track document destruction, default is false
    end

    class Contact
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :address
      field :city
      field :state
      embedded_in :contactable, polymorphic: true

      track_history on: :all,       # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: true,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false,    # track document destruction, default is false
                    scope: [:real_state, :company]
    end

    class User
      include Mongoid::Document
      has_many :companies, dependent: :destroy
      has_many :real_states, dependent: :destroy
    end
  end

  it "tracks history for nested embedded documents with polymorphic relations" do
    user = User.new
    user.save!

    real_state = user.real_states.build(name: 'rs_name')
    real_state.save!
    real_state.build_address(address: "Main Street #123", city: "Highland Park", state: 'IL').save!
    real_state.history_tracks.count.should eq(2)

    real_state.reload
    real_state.address.update_attribute(:address, 'Second Street')
    real_state.history_tracks.count.should eq(3)
    real_state.history_tracks.last.action.should == 'update'

    company = user.companies.build(name: 'co_name')
    company.save!
    company.build_address(address: "Main Street #456", city: "Evanston", state: 'IL').save!
    company.history_tracks.count.should eq(2)

    company.reload
    company.address.update_attribute(:address, 'Second Street')
    company.history_tracks.count.should eq(3)
    company.history_tracks.last.action.should == 'update'

    company.build_second_address(address: "Main Street #789", city: "Highland Park", state: 'IL').save!
    company.history_tracks.count.should eq(4)
    company.history_tracks.last.action.should eq('create')
    company.history_tracks.last.association_chain.last['name'].should eq('second_address')
  end
end
