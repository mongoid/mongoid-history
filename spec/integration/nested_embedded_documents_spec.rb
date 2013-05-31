require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Model
      include Mongoid::Document
      include Mongoid::History::Trackable
      
      field :name, type: String
      belongs_to :user, inverse_of: :models
      embeds_many :embones

      track_history   :on => :all,       # track title and body fields only, default is :all
                  :modifier_field => :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                  :version_field => :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                  :track_create   =>  false,    # track document creation, default is false
                  :track_update   =>  true,     # track document updates, default is true
                  :track_destroy  =>  false    # track document destruction, default is false
    end
    
    class Embone
      include Mongoid::Document
      include Mongoid::History::Trackable
      
      field :name
      embeds_many :embtwos
      embedded_in :model
      
      track_history   :on => :all,       # track title and body fields only, default is :all
                  :modifier_field => :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                  :version_field => :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                  :track_create   =>  false,    # track document creation, default is false
                  :track_update   =>  true,     # track document updates, default is true
                  :track_destroy  =>  false,    # track document destruction, default is false
                  :scope => :model
    end
    
    class Embtwo
      include Mongoid::Document
      include Mongoid::History::Trackable
      
      field :name
      embedded_in :embone
      
      track_history   :on => :all,       # track title and body fields only, default is :all
                  :modifier_field => :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                  :version_field => :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                  :track_create   =>  false,    # track document creation, default is false
                  :track_update   =>  true,     # track document updates, default is true
                  :track_destroy  =>  false,    # track document destruction, default is false
                  :scope => :model
    end
    
    class User
      include Mongoid::Document
      has_many :models, :dependent => :destroy, inverse_of: :user
    end
  end

  it "should be able to track history for nested embedded documents" do
    user = User.new
    user.save!
    
    model = Model.new({name: "m1name"})
    model.user = user
    model.save!
    embedded1 = model.embones.create({name: "e1name"})
    embedded2 = embedded1.embtwos.create({name: "e2name"})

    embedded2.name = "a new name"
    embedded2.save!
    
    model.history_tracks.first.undo! user
    embedded1.reload.name.should == "e1name"
    embedded2.reload.name.should == "e2name"
  end
end
