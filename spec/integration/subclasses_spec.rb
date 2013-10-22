require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Element
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :body

      track_history :on => [ :body ], :track_create => true, :track_update => true, :track_destroy => true
    end

    class Prompt < Element

    end
  end

  it "tracks subclass create and update" do
    prompt = Prompt.new
    expect { prompt.save! }.to change(Tracker, :count).by(1)
    expect { prompt.update_attributes!(body: "one") }.to change(Tracker, :count).by(1)
    prompt.undo!
    prompt.body.should be_blank
    prompt.redo! nil, 2
    prompt.body.should == "one"
    expect { prompt.destroy }.to change(Tracker, :count).by(1)
  end
end
