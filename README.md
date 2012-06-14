mongoid-history
===============

[![Build Status](https://secure.travis-ci.org/aq1018/mongoid-history.png?branch=master)](http://travis-ci.org/aq1018/mongoid-history) [![Dependency Status](https://gemnasium.com/aq1018/mongoid-history.png?travis)](https://gemnasium.com/aq1018/mongoid-history)


In frustration of Mongoid::Versioning, I created this plugin for tracking historical changes for any document, including embedded ones. It achieves this by storing all history tracks in a single collection that you define. Embedded documents are referenced by storing an association path, which is an array of `document_name` and `document_id` fields starting from the top most parent document and down to the embedded document that should track history.

This plugin also implements multi-user undo, which allows users to undo any history change in any order. Undoing a document also creates a new history track. This is great for auditing and preventing vandalism, but it is probably not suitable for use cases such as a wiki.

Note
----

**Please don't use 0.1.8 and 0.2.0.**

These versions won't work in Rails because there was an error in the sweeper that causes history tracker creation to fail. Upgrade to version 0.2.1 instead as it's able to track history on `embeds_one` documents correctly.

**Refactor in progress**

If you feel brave, you can look at the `refactor` branch and get a feel of what's coming. As I stated many times before, this gem was originally hacked up in one evening, and got patched many times by various fellow users. Thus the code has become pretty unmanagable over time.  The `refactor` branch tries repay this technical debt by breaking things down into smaller class and implement better tests. Stay tuned! :D

Upgrading from mongoid-history-0.1.x to >= 0.2
------------------------------------------------

If you are upgrading from 0.1.x to version 0.2.x and have existing data, run the following code **before** you start using 0.2.x. This is due to changes in `Mongoid::History::Tracker`'s `association_chain` field.

```ruby
Mongoid::History.tracker_class.all.each do |tracker|
  tracker.association_chain[1..-1].each do |node|
    node['name'] = node['name'].tableize
  end
  tracker.save!
end
```

Install
-------

This gem supports Ruby 1.8.7, 1.9.2, 1.9.3, JRuby and Rubinus. Add it to your `Gemfile` or run `gem install mongoid-history`.

```ruby
gem 'mongoid-history'
```

Usage
-----

Here is a quick example on how to use this plugin.

**Create a history tracker**

Create a new class to track histories. All histories are stored in this tracker. The name of the class can be anything you like. The only requirement is that it includes `Mongoid::History::Tracker`

```ruby
# app/models/history_tracker.rb
class HistoryTracker
  include Mongoid::History::Tracker
end
```

**Set tracker class name**

You should manually set the tracker class name to make sure your tracker can be found and loaded properly. You can skip this step if you manually require your tracker before using any trackables.

The following example sets the tracker class name using a Rails initializer.

```ruby
# config/initializers/mongoid-history.rb
# initializer for mongoid-history
# assuming HistoryTracker is your tracker class
Mongoid::History.tracker_class_name = :history_tracker
```

**Set `#current_user` method name**

You can set the name of the method that returns currently logged in user if you don't want to set `modifier` explicitly on every update.

The following example sets the `current_user_method` using a Rails initializer

```ruby
# config/initializers/mongoid-history.rb
# initializer for mongoid-history
# assuming you're using devise/authlogic
Mongoid::History.current_user_method = :current_user
```

When `current_user_method` is set, mongoid-history will invoke this method on each update and set its result as the instance modifier.

```ruby
# assume that current_user return #<User _id: 1>
post = Post.first
post.update_attributes(:title => 'New title')

post.history_tracks.last.modifier #=> #<User _id: 1>
```

**Create trackable classes and objects**

```ruby
class Post
  include Mongoid::Document
  include Mongoid::Timestamps

  # history tracking all Post documents
  # note: tracking will not work until #track_history is invoked
  include Mongoid::History::Trackable

  field           :title
  field           :body
  field           :rating
  embeds_many     :comments

  # telling Mongoid::History how you want to track changes
  track_history   :on => [:title, :body],       # track title and body fields only, default is :all
                  :modifier_field => :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                  :version_field => :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                  :track_create   =>  false,    # track document creation, default is false
                  :track_update   =>  true,     # track document updates, default is true
                  :track_destroy  =>  false,    # track document destruction, default is false
end

class Comment
  include Mongoid::Document
  include Mongoid::Timestamps

  # declare that we want to track comments
  include Mongoid::History::Trackable

  field             :title
  field             :body
  embedded_in       :post, :inverse_of => :comments

  # track title and body for all comments, scope it to post (the parent)
  # also track creation and destruction
  track_history     :on => [:title, :body], :scope => :post, :track_create => true, :track_destroy => true
end

# the modifier class
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
For more examples, check out [spec/integration/integration_spec.rb](https://github.com/aq1018/mongoid-history/blob/master/spec/integration/integration_spec.rb).

Contributing to mongoid-history
-------------------------------

* Check out the latest code to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Create a feature/bugfix branch.
* Commit and push until you are happy with your changes.
* Make sure to add tests.
* Update the CHANGELOG for the next release.
* Try not to mess with the Rakefile or version.
* Make a pull request.

Copyright
---------

Copyright (c) 2011-2012 Aaron Qian. MIT License. 
See [LICENSE.txt](https://github.com/aq1018/mongoid-history/blob/master/LICENSE.txt) for further details.

