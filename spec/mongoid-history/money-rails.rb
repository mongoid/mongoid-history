require 'spec_helper'
require 'money-rails'


class MyModel
   include Mongoid::Document
   include Mongoid::Timestamps
   include Mongoid::History::Trackable

   field :name, type: String
   field :date, type: Date 
   field :amount, type: Money

   track_history track_create: true
end

describe "Model with MoneyRails field" do
  before(:example) do
    @my=MyModel.create(name: "A", date: Date.today, amount: 200.to_money)
  end
  
  it "should have a valid amount field with class Money" do
    @my.date.class.should eq(Date)
    @my.amount.class.should eq(Money)
  end
  
  it "should have a history entry with a valid amount field with class Money " do 
    @my.history_tracks.last[:modified][:date].class.should eq (Time)
    @my.history_tracks.last[:modified][:amount].class.should eq(Money)
  end
end