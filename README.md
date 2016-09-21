mongoid-history
===============

[![Gem Version](https://badge.fury.io/rb/mongoid-history.svg)](http://badge.fury.io/rb/mongoid-history)
[![Build Status](https://secure.travis-ci.org/mongoid/mongoid-history.svg?branch=master)](http://travis-ci.org/mongoid/mongoid-history)
[![Dependency Status](https://gemnasium.com/mongoid/mongoid-history.svg)](https://gemnasium.com/mongoid/mongoid-history)
[![Code Climate](https://codeclimate.com/github/mongoid/mongoid-history.svg)](https://codeclimate.com/github/mongoid/mongoid-history)
[![Coverage Status](https://coveralls.io/repos/mongoid/mongoid-history/badge.svg)](https://coveralls.io/r/mongoid/mongoid-history?branch=coveralls)

Mongoid-history tracks historical changes for any document, including embedded ones. It achieves this by storing all history tracks in a single collection that you define. Embedded documents are referenced by storing an association path, which is an array of `document_name` and `document_id` fields starting from the top most parent document and down to the embedded document that should track history.

This gem also implements multi-user undo, which allows users to undo any history change in any order. Undoing a document also creates a new history track. This is great for auditing and preventing vandalism, but is probably not suitable for use cases such as a wiki (but we won't stop you either).

Install
-------

This gem supports Mongoid 3, 4 and 5 on Ruby 1.9.3 or newer. Add it to your `Gemfile` or run `gem install mongoid-history`.

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

**Set default tracker class name (Optional)**

Mongoid::History will use the first loaded class to include Mongoid::History::Tracker as the
default history tracker. If you are using multiple Tracker classes and would like to set
a global default you may do so in a Rails initializer:

```ruby
# config/initializers/mongoid_history.rb
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
  # dynamic fields will be tracked automatically (for MongoId 4.0+ you should include Mongoid::Attributes::Dynamic to your model)
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

# undo comment to version 1 without save
comment.undo nil, from: 1, to: comment.version

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

You may want to track changes on all fields.

```ruby
class Post
  include Mongoid::Document
  include Mongoid::History::Trackable

  field           :title
  field           :body
  field           :rating

  track_history   :on => [:fields] # all fields will be tracked
end
```

You can also track changes on all embedded relations.

```ruby
class Post
  include Mongoid::Document
  include Mongoid::History::Trackable

  embeds_many :comments
  embeds_one  :content

  track_history   :on => [:embedded_relations] # all embedded relations will be tracked
end
```

**Include embedded objects attributes in parent audit**

Modify above `Post` and `Comment` classes as below:

```ruby
class Post
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::History::Trackable

  field           :title
  field           :body
  field           :rating
  embeds_many     :comments

  track_history   :on => [:title, :body, :comments],
                  :modifier_field => :modifier,
                  :modifier_field_inverse_of => :nil,
                  :version_field => :version,
                  :track_create   =>  true,     # track create on Post
                  :track_update   =>  true,
                  :track_destroy  =>  false
end

class Comment
  include Mongoid::Document
  include Mongoid::Timestamps

  field             :title
  field             :body
  embedded_in       :post, :inverse_of => :comments
end

user = User.create(:name => "Aaron")
post = Post.create(:title => "Test", :body => "Post", :modifier => user)
comment = post.comments.build(:title => "test", :body => "comment", :modifier => user)
post.save
post.history_tracks.count # should be 1

comment.respond_to?(:history_tracks) # should be false

track = post.history_tracks.first
track.original # {}
track.modified # { "title" => "Test", "body" => "Post", "comments" => [{ "_id" => "575fa9e667d827e5ed00000d", "title" => "test", "body" => "comment" }], ... }
```

**Whitelist the tracked attributes of embedded relations**

If you don't want to track all the attributes of embedded relations in parent audit history, you can whitelist the attributes as below:

```ruby
class Book
  include Mongoid::Document
  ...
  embeds_many :pages
  track_history :on => { :pages => [:title, :content] }
end

class Page
  include Mongoid::Document
  ...
  field :number
  field :title
  field :subtitle
  field :content
  embedded_in :book
end
```

It will now track only `_id` (Mandatory), `title` and `content` attributes for `pages` relation.

**Retrieving the list of tracked static and dynamic fields**

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

**Retrieving the list of tracked relations**

```ruby
class Book
  ...
  track_history :on => [:pages]
end

Book.tracked_relation?(:pages)    #=> true
Book.tracked_embeds_many          #=> ["pages"]
Book.tracked_embeds_many?(:pages) #=> true
```

**Skip soft-deleted embedded objects with nested tracking**

Default paranoia field is `deleted_at`. You can use custom field for each class as below:

```ruby
class Book
  include Mongoid::Document
  include Mongoid::History::Trackable
  embeds_many :pages
  track_history on: :pages
end

class Page
  include Mongoid::Document
  include Mongoid::History::Trackable
  ...
  embedded_in :book
  history_settings paranoia_field: :removed_at
end
```

This will skip the `page` documents with `removed_at` set to a non-blank value from nested tracking

**Formatting fields**

You can opt to use a proc or string interpolation to alter attributes being stored on a history record.

```ruby
class Post
  include Mongoid::Document
  include Mongoid::History::Trackable

  field           :title
  track_history   on: :title,
                  format: { title: ->(t){ t[0..3] } }
```

This also works for fields on an embedded relations.

```ruby
class Book
  include Mongoid::Document
  include Mongoid::History::Trackable

  embeds_many :pages
  track_history on: :pages,
                format: { pages: { number: 'pg. %d' } }
end

class Page
  include Mongoid::Document
  include Mongoid::History::Trackable

  field :number, type: Integer
  embedded_in :book
end
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

Note: Specify additional fields that are provided with a custom `changes_method` with the `:on` option.. To specify current fields and additional fields, use `fields.keys + [:custom]`

Example:

```ruby
class Foo
  include Mongoid::Document
  include Mongoid::History::Trackable

  attr_accessor :ip

  track_history on: [:ip], changes_method: :my_changes

  def my_changes
    unless ip.nil?
      changes.merge(ip: [nil, ip])
    else
      changes
    end
  end
end
```

Example with embedded & nested attributes:

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
  track_history   on: fields.keys + [:baz], changes_method: :changes_with_baz

  def changes_with_baz
    if baz.changed?
      changes.merge(baz: summarized_changes(baz))
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

For more examples, check out [spec/integration/integration_spec.rb](spec/integration/integration_spec.rb).


**Thread Safety**

Mongoid::History stores the tracking enable/disable flag in `Thread.current`.
If the [RequestStore](https://github.com/steveklabnik/request_store) gem is installed, Mongoid::History
will automatically store variables in the `RequestStore.store` instead. RequestStore is recommended
for threaded web servers like Thin or Puma.


Contributing to mongoid-history
-------------------------------

You're encouraged to contribute to this library. See [CONTRIBUTING](CONTRIBUTING.md) for details.

Copyright
---------

Copyright (c) 2011-2016 Aaron Qian and Contributors.

MIT License. See [LICENSE.txt](LICENSE.txt) for further details.
