mongoid-history
===============

[![Gem Version](https://badge.fury.io/rb/mongoid-history.png)](http://badge.fury.io/rb/mongoid-history)
[![Build Status](https://secure.travis-ci.org/aq1018/mongoid-history.png?branch=master)](http://travis-ci.org/aq1018/mongoid-history)
[![Dependency Status](https://gemnasium.com/aq1018/mongoid-history.png)](https://gemnasium.com/aq1018/mongoid-history)
[![Code Climate](https://codeclimate.com/github/aq1018/mongoid-history.png)](https://codeclimate.com/github/aq1018/mongoid-history)
[![Coverage Status](https://coveralls.io/repos/aq1018/mongoid-history/badge.png?branch=coveralls)](https://coveralls.io/r/aq1018/mongoid-history?branch=coveralls)

Mongoid-history tracks historical changes for any document, including embedded ones. It achieves this by storing all history tracks in a single collection that you define. Embedded documents are referenced by storing an association path, which is an array of `document_name` and `document_id` fields starting from the top most parent document and down to the embedded document that should track history.

This gem also implements multi-user undo, which allows users to undo any history change in any order. Undoing a document also creates a new history track. This is great for auditing and preventing vandalism, but is probably not suitable for use cases such as a wiki (but we won't stop you either).

Stable Release
--------------

You're reading the documentation the 0.4.x release that supports Mongoid 3.x and 4.x. For 2.x compatible mongoid-history, please use a 0.2.x version from the [2.x-stable branch](https://github.com/aq1018/mongoid-history/tree/2.4-stable).

Install
-------

This gem supports Mongoid 3.x and 4.x on Ruby 1.9.3 or newer. Add it to your `Gemfile` or run `gem install mongoid-history`.

```ruby
gem 'mongoid-history'
```

Usage
-----

**Create a history tracker**

Create a new class to track histories. All histories are stored in this tracker. The name of the class can be anything you like. The only requirement is that it includes `Mongoid::History::Tracker`

```ruby
# app/models/history_tracker.rb
class HistoryTracker
  include Mongoid::History::Tracker
end
```

**Set tracker class name**

Manually set the tracker class name to make sure your tracker can be found and loaded properly. You can skip this step if you manually require your tracker before using any trackables.

The following example sets the tracker class name using a Rails initializer.

```ruby
# config/initializers/mongoid-history.rb
# initializer for mongoid-history
# assuming HistoryTracker is your tracker class
Mongoid::History.tracker_class_name = :history_tracker
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
                  :modifier_field => :modifier, # adds "belongs_to :modifier" to track who made the change, default is :modifier
                  :modifier_field_inverse_of => :nil, # adds an ":inverse_of" option to the "belongs_to :modifier" relation, default is not set
                  :version_field => :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                  :track_create   =>  false,    # track document creation, default is false
                  :track_update   =>  true,     # track document updates, default is true
                  :track_destroy  =>  false     # track document destruction, default is false
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

  # For embedded polymorphic relations, specify an array of model names or its polymorphic name
  # e.g. :scope => [:post, :image, :video]
  #      :scope => :commentable

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

# redo version 1
comment.redo! user, 1

# delete post
post.destroy

# undelete post
post.undo! user

# disable tracking for comments within a block
Comment.disable_tracking do
  comment.update_attributes(:title => "Test 3")
end

# globally disable all history tracking
Mongoid::History.disable do
  comment.update_attributes(:title => "Test 3")
  user.update_attributes(:name => "Eddie Van Halen")
end
```

**Retrieving the list of tracked fields**

```ruby
class Book
  ...
  field             :title
  field             :author
  field             :price
  track_history     :on => [:title, :price]
end

Book.tracked_fields           #=> ["title", "price"]
Book.tracked_field?(:title)   #=> true
Book.tracked_field?(:author)  #=> false
```

**Displaying history trackers as an audit trail**

In your Controller:

```ruby
# Fetch history trackers
@trackers = HistoryTracker.limit(25)

# get change set for the first tracker
@changes = @trackers.first.tracked_changes
  #=> {field: {to: val1, from: val2}}

# get edit set for the first tracker
@edits = @trackers.first.tracked_edits
  #=> { add: {field: val},
  #     remove: {field: val},
  #     modify: { to: val1, from: val2 },
  #     array: { add: [val2], remove: [val1] } }
```

In your View, you might do something like (example in HAML format):

```haml
%ul.changes
  - (@edits[:add]||[]).each do |k,v|
    %li.remove Added field #{k} value #{v}

  - (@edits[:modify]||[]).each do |k,v|
    %li.modify Changed field #{k} from #{v[:from]} to #{v[:to]}

  - (@edits[:array]||[]).each do |k,v|
    %li.modify
      - if v[:remove].nil?
        Changed field #{k} by adding #{v[:add]}
      - elsif v[:add].nil?
        Changed field #{k} by removing #{v[:remove]}
      - else
        Changed field #{k} by adding #{v[:add]} and removing #{v[:remove]}

  - (@edits[:remove]||[]).each do |k,v|
    %li.remove Removed field #{k} (was previously #{v})
```

**Adding Userstamp on History Trackers**

To track the User in the application who created the HistoryTracker, please add the
[Mongoid::Userstamp gem](https://github.com/tbpro/mongoid_userstamp) to your HistoryTracker class.
This will add a field called `created_by` and an accessor `creator` to the model (you can rename these via gem config).

```
class MyHistoryTracker
  include Mongoid::History::Tracker
  include Mongoid::Userstamp
end
```

*Migrating Userstamp from Previous Versions*

Since October 2013 (mongoid-history version 0.4.1 and onwards), Mongoid::History itself no longer supports the userstamp natively. In order to migrate, follow the
instructions above then run the following command:

```
MyHistoryTracker.all.each{|ht| ht.rename(:modifier_id, :created_by)
```

**Setting Modifier Class Name**

If your app will track history changes to a user, Mongoid History looks for these modifiers in the ``User`` class by default.  If you have named your 'user' accounts differently, you will need to add that to your Mongoid History config:

The following examples set the modifier class name using a Rails initializer:

If your app uses a class ``Author``:

```ruby
# config/initializers/mongoid-history.rb
# initializer for mongoid-history

Mongoid::History.modifier_class_name = 'Author'
```

Or perhaps you are namespacing to a module:

```ruby
Mongoid::History.modifier_class_name = 'CMS::Author'
```

**Using an alternate changes method**

Sometimes you may wish to provide an alternate method for determining which changes should be tracked.  For example, if you are using embedded documents
and nested attributes, you may wish to write your own changes method that includes changes from the embedded documents.

Mongoid::History provides an option named `:changes_method` which allows you to do this.  It defaults to `:changes`, which is the standard changes method.

Example:

```ruby
class Foo
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::History::Trackable

  field      :bar
  embeds_one :baz
  accepts_nested_attributes_for :baz

  # use changes_with_baz to include baz's changes in this document's
  # history.
  track_history     :changes_method => :changes_with_baz

  def changes_with_baz
    if baz.changed?
      changes.merge( :baz => summarized_changes(baz) )
    else
      changes
    end
  end

  private
  # This method takes the changes from an embedded doc and formats them
  # in a summarized way, similar to how the embedded doc appears in the
  # parent document's attributes
  def summarized_changes obj
    obj.changes.keys.map do |field|
      next unless obj.respond_to?("#{field}_change")
      [ { field => obj.send("#{field}_change")[0] },
        { field => obj.send("#{field}_change")[1] } ]
    end.compact.transpose.map do |fields|
      fields.inject({}) {|map,f| map.merge(f)}
    end
  end
end

class Baz
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :foo
  field :value
end
```

For more examples, check out [spec/integration/integration_spec.rb](https://github.com/aq1018/mongoid-history/blob/master/spec/integration/integration_spec.rb).

Contributing to mongoid-history
-------------------------------

You're encouraged to contribute to this library. See [CONTRIBUTING](CONTRIBUTING.md) for details.

Copyright
---------

Copyright (c) 2011-2012 Aaron Qian. MIT License.

See [LICENSE.txt](https://github.com/aq1018/mongoid-history/blob/master/LICENSE.txt) for further details.



[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/aq1018/mongoid-history/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
