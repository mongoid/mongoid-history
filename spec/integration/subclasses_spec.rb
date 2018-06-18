require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Element
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :body

      track_history on: [:body], track_create: true, track_update: true, track_destroy: true
    end

    class Prompt < Element
    end

    class User
      include Mongoid::Document
    end
  end

  let(:user) { User.create! }

  it 'tracks subclass create and update' do
    prompt = Prompt.new(modifier: user)
    expect { prompt.save! }.to change(Tracker, :count).by(1)
    expect { prompt.update_attributes!(body: 'one') }.to change(Tracker, :count).by(1)
    prompt.undo! user
    expect(prompt.body).to be_blank
    prompt.redo! user, 2
    expect(prompt.body).to eq('one')
    expect { prompt.destroy }.to change(Tracker, :count).by(1)
  end

  after :all do
    Object.send(:remove_const, :Element)
    Object.send(:remove_const, :Prompt)
    Object.send(:remove_const, :User)
  end
end
