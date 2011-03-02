require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongoid::History do
  before :all do
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
  end
  
  
end
