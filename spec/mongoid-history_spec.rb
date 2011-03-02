require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class HistoryTracker
  include Mongoid::History::Tracker
end

class Post
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::History::Trackable
  
  field           :title
  field           :body
  embeds_many     :comments
  referenced_in   :user
  track_history   :on => [:title, :body]
end

class Comment
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::History::Trackable
  
  field             :title
  field             :body
  embedded_in       :post, :inverse_of => :comments
  referenced_in     :user
  track_history     :on => [:title, :body], :scope => :post
end

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field             :name
end

describe Mongoid::History::Tracker do
  describe Mongoid::History::Tracker do
    it "should set tracker_class_name when included" do
      Mongoid::History.tracker_class_name.should == :history_tracker
    end
  end
  
  describe Mongoid::History::Trackable do
    it "should append trackable_classes when included" do
      Mongoid::History.trackable_classes.should == [Post, Comment]
    end
  end
end
