require 'spec_helper'

describe Mongoid::History::Tracker do
  before :each do
    class RealState
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user
      embeds_one :address, class_name: 'Contact', as: :contactable
      embeds_one :embone, as: :embedable

      track_history
    end

    class Company
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      belongs_to :user
      embeds_one :address, class_name: 'Contact', as: :contactable
      embeds_one :second_address, class_name: 'Contact', as: :contactable
      embeds_one :embone, as: :embedable

      track_history
    end

    class Embone
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embedded_in :embedable, polymorphic: true

      track_history scope: :embedable
    end

    class Contact
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :address
      field :city
      field :state
      embedded_in :contactable, polymorphic: true

      track_history scope: %i[real_state company]
    end

    class User
      include Mongoid::Document
      has_many :companies, dependent: :destroy
      has_many :real_states, dependent: :destroy
    end
  end

  after :each do
    Object.send(:remove_const, :RealState)
    Object.send(:remove_const, :Company)
    Object.send(:remove_const, :Embone)
    Object.send(:remove_const, :Contact)
    Object.send(:remove_const, :User)
  end

  let!(:user) { User.create! }

  it 'tracks history for nested embedded documents with polymorphic relations' do
    real_state = user.real_states.build(name: 'rs_name', modifier: user)
    real_state.save!
    real_state.build_address(address: 'Main Street #123', city: 'Highland Park', state: 'IL', modifier: user).save!
    expect(real_state.history_tracks.count).to eq(2)
    expect(real_state.address.history_tracks.count).to eq(1)

    real_state.reload
    real_state.address.update_attributes!(address: 'Second Street', modifier: user)
    expect(real_state.history_tracks.count).to eq(3)
    expect(real_state.address.history_tracks.count).to eq(2)
    expect(real_state.history_tracks.last.action).to eq('update')

    real_state.build_embone(name: 'Lorem ipsum', modifier: user).save!
    expect(real_state.history_tracks.count).to eq(4)
    expect(real_state.embone.history_tracks.count).to eq(1)
    expect(real_state.embone.history_tracks.last.action).to eq('create')
    expect(real_state.embone.history_tracks.last.association_chain.last['name']).to eq('embone')

    company = user.companies.build(name: 'co_name', modifier: user)
    company.save!
    company.build_address(address: 'Main Street #456', city: 'Evanston', state: 'IL', modifier: user).save!
    expect(company.history_tracks.count).to eq(2)
    expect(company.address.history_tracks.count).to eq(1)

    company.reload
    company.address.update_attributes!(address: 'Second Street', modifier: user)
    expect(company.history_tracks.count).to eq(3)
    expect(company.address.history_tracks.count).to eq(2)
    expect(company.history_tracks.last.action).to eq('update')

    company.build_second_address(address: 'Main Street #789', city: 'Highland Park', state: 'IL', modifier: user).save!
    expect(company.history_tracks.count).to eq(4)
    expect(company.second_address.history_tracks.count).to eq(1)
    expect(company.second_address.history_tracks.last.action).to eq('create')
    expect(company.second_address.history_tracks.last.association_chain.last['name']).to eq('second_address')

    company.build_embone(name: 'Lorem ipsum', modifier: user).save!
    expect(company.history_tracks.count).to eq(5)
    expect(company.embone.history_tracks.count).to eq(1)
    expect(company.embone.history_tracks.last.action).to eq('create')
    expect(company.embone.history_tracks.last.association_chain.last['name']).to eq('embone')
  end
end
