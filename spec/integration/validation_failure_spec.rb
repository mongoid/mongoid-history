require 'spec_helper'

describe Mongoid::History::Tracker do
  before :each do
    class Element
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::History::Trackable

      field :title
      field :body

      validates :title, presence: true

      if Mongoid::Compatibility::Version.mongoid7_or_newer?
        has_many :items, dependent: :restrict_with_exception
      else
        has_many :items, dependent: :restrict
      end

      track_history on: [:body]
    end

    class Item
      include Mongoid::Document
      include Mongoid::Timestamps

      belongs_to :element
    end

    class Prompt < Element
    end

    class User
      include Mongoid::Document
    end
  end

  after :each do
    Object.send(:remove_const, :Element)
    Object.send(:remove_const, :Item)
    Object.send(:remove_const, :Prompt)
    Object.send(:remove_const, :User)
  end

  let(:user) { User.create! }

  it 'does not track delete when parent class validation fails' do
    prompt = Prompt.new(title: 'first', modifier: user)
    expect { prompt.save! }.to change(Tracker, :count).by(1)
    expect do
      expect { prompt.update_attributes!(title: nil, body: 'one') }
        .to raise_error(Mongoid::Errors::Validations)
    end.to change(Tracker, :count).by(0)
  end

  it 'does not track delete when parent class restrict dependency fails' do
    prompt = Prompt.new(title: 'first', modifier: user)
    prompt.items << Item.new
    expect { prompt.save! }.to change(Tracker, :count).by(1)
    expect(prompt.version).to eq(1)
    expect do
      expect { prompt.destroy }.to raise_error(Mongoid::Errors::DeleteRestriction)
    end.to change(Tracker, :count).by(0)
  end

  it 'does not track delete when restrict dependency fails' do
    elem = Element.new(title: 'first', modifier: user)
    elem.items << Item.new
    expect { elem.save! }.to change(Tracker, :count).by(1)
    expect(elem.version).to eq(1)
    expect do
      expect { elem.destroy }.to raise_error(Mongoid::Errors::DeleteRestriction)
    end.to change(Tracker, :count).by(0)
  end
end
