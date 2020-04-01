require 'spec_helper'

describe Mongoid::History::Tracker do
  before :each do
    class Element
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      track_history

      field :body

      # force preparation of options
      history_trackable_options
    end

    class Prompt < Element
      field :head
    end

    class User
      include Mongoid::Document
    end
  end

  after :each do
    Object.send(:remove_const, :Element)
    Object.send(:remove_const, :Prompt)
    Object.send(:remove_const, :User)
  end

  let(:user) { User.create! }

  it 'tracks subclass create and update' do
    prompt = Prompt.new(modifier: user)
    expect { prompt.save! }.to change(Tracker, :count).by(1)
    expect { prompt.update_attributes!(body: 'one', head: 'two') }.to change(Tracker, :count).by(1)
    prompt.undo! user
    expect(prompt.body).to be_blank
    expect(prompt.head).to be_blank
    prompt.redo! user, 2
    expect(prompt.body).to eq('one')
    expect(prompt.head).to eq('two')
    expect { prompt.destroy }.to change(Tracker, :count).by(1)
  end
end
