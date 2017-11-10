require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Element
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :title
      field :body

      validates :title, presence: true

      has_many :items, dependent: :restrict

      track_history on: [:body], track_create: true, track_update: true, track_destroy: true
    end

    class Item
      include Mongoid::Document
      include Mongoid::Timestamps

      belongs_to :element
    end

    class Prompt < Element
    end

    @persisted_history_options = Mongoid::History.trackable_class_options
  end

  before(:each) { Mongoid::History.trackable_class_options = @persisted_history_options }

  it 'does not track delete when parent class validation fails' do
    prompt = Prompt.new(title: 'first')
    expect { prompt.save! }.to change(Tracker, :count).by(1)
    expect do
      expect { prompt.update_attributes!(title: nil, body: 'one') }
        .to raise_error(Mongoid::Errors::Validations)
    end.to change(Tracker, :count).by(0)
  end

  it 'does not track delete when parent class restrict dependency fails' do
    prompt = Prompt.new(title: 'first')
    prompt.items << Item.new
    expect { prompt.save! }.to change(Tracker, :count).by(1)
    expect(prompt.version).to eq(1)
    expect do
      expect { prompt.destroy }.to raise_error(Mongoid::Errors::DeleteRestriction)
    end.to change(Tracker, :count).by(0)
  end

  it 'does not track delete when restrict dependency fails' do
    elem = Element.new(title: 'first')
    elem.items << Item.new
    expect { elem.save! }.to change(Tracker, :count).by(1)
    expect(elem.version).to eq(1)
    expect do
      expect { elem.destroy }.to raise_error(Mongoid::Errors::DeleteRestriction)
    end.to change(Tracker, :count).by(0)
  end
end
