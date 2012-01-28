mongoid-history
===============

[![Build Status](https://secure.travis-ci.org/aq1018/mongoid-history.png?branch=master)](http://travis-ci.org/aq1018/mongoid-history) [![Dependency Status](https://gemnasium.com/aq1018/mongoid-history.png?travis)](https://gemnasium.com/aq1018/mongoid-history)


In frustration of Mongoid::Versioning, I created this plugin for tracking historical changes for any document, including embedded ones. It achieves this by storing all history tracks in a single collection that you define. (See Usage for more details) Embedded documents are referenced by storing an association path, which is an array of document_name and document_id fields starting from the top most parent document and down to the embedded document that should track history.

This plugin implements multi-user undo, which allows users to undo any history change in any order. Undoing a document also creates a new history track. This is great for auditing and preventing vandalism, but it is probably not suitable for use cases such as a wiki.

Install
-------

```
gem install mongoid-history
```

Rails 3
-------

In your Gemfile:

```ruby
gem 'mongoid-history'
```

Usage
-----

Here is a quick example on how to use this plugin. For more details, please look at spec/integration/integration_spec.rb. It offers more detailed examples on how to use `Mongoid::History`.

**Create a History Tracker**

Create a new class to track histories. All histories are stored in this tracker. The name of the class can be anything you like. The only requirement is that it includes `Mongoid::History::Tracker`

```ruby
# app/models/history_tracker.rb
class HistoryTracker
  include Mongoid::History::Tracker
end
```

**Set Tracker Class Name**


You should manually set the tracker class name to make sure your tracker can be found and loaded properly. You can skip this step if you manually require your tracker before using any trackables. If you don't know what I'm talking about, then you should just follow the example below.

Here is an example of setting the tracker class name using a rails initializer

```ruby
# config/initializers/mongoid-history.rb
# initializer for mongoid-history
# assuming HistoryTracker is your tracker class
Mongoid::History.tracker_class_name = :history_tracker
```

**Set `#current_user` method name**

You can set name of method which returns currently logged in user if you don't want to set modifier explicitly on every update.

Here is an example of setting the current_user_method using a rails initializer

```ruby
# config/initializers/mongoid-history.rb
# initializer for mongoid-history
# assuming you're using devise/authlogic
Mongoid::History.current_user_method = :current_user
```

When current_user_method is set mongoid-history call this method on each update and set it as modifier

```
# Assume that current_user return #<User _id: 1>
post = Post.first
post.update_attributes(:title => 'New title')

post.history_tracks.last.modifier #=> #<User _id: 1>
```

***Create Trackable classes and objects***

```ruby
class Post
  include Mongoid::Document
  include Mongoid::Timestamps

  # History tracking all Post Documents
  # Note: Tracking will not work until #track_history is invoked
  include Mongoid::History::Trackable

  field           :title
  field           :body
  field           :rating
  embeds_many     :comments

  # Telling Mongoid::History how you want to track
  track_history   :on => [:title, :body],       # I want to track title and body fields only. Default is :all
                  :modifier_field => :modifier, # Adds "referened_in :modifier" to track who made the change. Default is :modifier
                  :version_field => :version,   # Adds "field :version, :type => Integer" to track current version. Default is :version
                  :track_create   =>  false,    # Do you want to track document creation? Default is false
                  :track_update   =>  true,     # Do you want to track document updates? Default is true
                  :track_destroy  =>  false,    # Do you want to track document destruction? Default is false
end

class Comment
  include Mongoid::Document
  include Mongoid::Timestamps

  # Declare that we want to track comments
  include Mongoid::History::Trackable

  field             :title
  field             :body
  embedded_in       :post, :inverse_of => :comments

  # Track title and body for all comments, scope it to post (the parent)
  # Also track creation and destruction
  track_history     :on => [:title, :body], :scope => :post, :track_create => true, :track_destroy => true
end

# The modifier can be specified as well
class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field             :name
end

user = User.create(:name => "Aaron")
post = Post.create(:title => "Test", :body => "Post", :modifier => user)
comment = post.comments.create(:title => "test", :body => "comment", :modifier => user)
comment.history_tracks.count # should be 1

comment.update_attributes(:title => "Test 2")
comment.history_tracks.count # should be 2

track = comment.history_tracks.last

track.undo! user # comment title should be "Test"

track.redo! user # comment title should be "Test 2"

# undo last change
comment.undo! user

# undo versions 1 - 4
comment.undo! user, :from => 4, :to => 1

# undo last 3 versions
comment.undo! user, :last => 3

# redo versions 1 - 4
comment.redo! user, :from => 1, :to => 4

# redo last 3 versions
comment.redo! user, :last => 3

# delete post
post.destroy

# undelete post
post.undo! user

# disable tracking for comments within a block
Comment.disable_tracking do
  comment.update_attributes(:title => "Test 3")
end
```

Contributing to mongoid-history
-------------------------------

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

Copyright
---------

Copyright (c) 2011 Aaron Qian. See LICENSE.txt for
further details.

