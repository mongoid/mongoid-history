# Mongoid History

[![Gem Version](https://badge.fury.io/rb/mongoid-history.svg)](http://badge.fury.io/rb/mongoid-history)
[![CI](https://github.com/mongoid/mongoid-history/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/mongoid/mongoid-history/actions/workflows/test.yml?query=branch%3Amaster)
[![Coverage Status](https://coveralls.io/repos/github/mongoid/mongoid-history/badge.svg?branch=master)](https://coveralls.io/github/mongoid/mongoid-history?branch=master)

Mongoid History tracks historical changes for any document, including embedded ones. It achieves this by storing all history tracks in a single collection that you define. Embedded documents are referenced by storing an association path, which is an array of `document_name` and `document_id` fields starting from the top most parent document and down to the embedded document that should track history.

This gem also implements multi-user undo, which allows users to undo any history change in any order. Undoing a document also creates a new history track. This is great for auditing and preventing vandalism, but is probably not suitable for use cases such as a wiki (but we won't stop you either).

### Version Support

Mongoid History supports the following dependency versions:

* Ruby 2.3+
* Mongoid 3.1+
* Recent JRuby versions

Earlier Ruby versions may work but are untested.

### Tracking Boundaries

History is recorded by Mongoid's create, update, and destroy callbacks. Use callback-based persistence, such as `create!`, `update_attributes!`, `save!`, and `destroy`, when changes must be tracked:

```ruby
post.update_attributes!(title: 'A tracked edit')
Post.where(published: false).each do |post|
  post.update_attributes!(published: true)
end
```

Atomic operations such as `post.set`, criteria operations such as `update_all`, and direct driver operations such as `collection.bulk_write` bypass these callbacks. They persist changes without creating history or incrementing the history version. Enabling tracking does not change this behavior. A subsequent callback-based update cannot reconstruct the missing edits. Iterating and saving documents is not a bulk-write equivalent: it runs validations and callbacks and is not atomic across documents.

Mongoid History does not wrap driver writes or synthesize history by reading documents before a bulk operation. Such a read can race with concurrent writes; ordered or unordered bulk writes can partially succeed, and their result does not provide every document's before-and-after values. Applications requiring auditing for all database writers need a separate capture design with explicit consistency, failure, and recovery guarantees.

### Storage and Audit Presentation

Trackers are Mongoid documents, not a pluggable storage interface. Custom tracker classes can select a MongoDB collection or client using Mongoid's `store_in`, but cannot replace MongoDB with Cassandra or another database. A non-MongoDB adapter would also need compatible queries, association traversal, ordering, undo/redo, and failure semantics; changing only the insertion path is insufficient.

The persisted `original`, `modified`, `action`, and `association_chain` fields describe individual edits, including edits to embedded documents. They are not whole-root snapshots. Replacing them with a single nested tree would change the storage format and the independent, non-linear undo behavior. For a human-readable audit trail, use `tracked_changes` or `tracked_edits` (see below) and build a presentation layer without rewriting the stored edits. An external archive or derived tree is not a supported replacement for the records required by undo/redo.

## Install

```ruby
gem 'mongoid-history'
```

## Usage

### Create a history tracker

Create a new class to track histories. All histories are stored in this tracker. The name of the class can be anything you like. The only requirement is that it includes `Mongoid::History::Tracker`

```ruby
# app/models/history_tracker.rb
class HistoryTracker
  include Mongoid::History::Tracker
end
```

### Group changes for reporting

Use `Mongoid::History.with_group('editing-session-id') { document.update_attributes!(title: 'New title') }` to tag history records with a `group_id`. Reuse the same application-provided string in separate requests to collect changes from an editing session. Query `document.history_tracks.where(group_id: 'editing-session-id')` or the tracker class directly. The block returns its result and restores any enclosing group even on exceptions; storage follows the existing RequestStore/thread-local tracking settings.

Grouping is presentation metadata, not a transaction: each write retains its own history record, version, modifier, undo and redo. Records are not automatically merged by time or modifier, and a failed block does not roll back earlier successful writes. Group IDs do not grant authorization; scope queries to documents/users the caller may access. Existing records have no group. Add a database index on `group_id` in your tracker if your application's reporting queries require it.

### Track has_and_belongs_to_many references

Track a HABTM association's stored ID array with `track_history on: [:tags]`, its foreign key (`on: [:tag_ids]`), or `on: :referenced_relations` for all HABTM associations. The default `on: :all` already includes these stored fields. Relation names in `except` and `format` also resolve to the foreign key, including custom foreign keys. This tracks membership IDs, not changes to fields on referenced documents.

Use document saves to record membership changes: `post.update_attributes!(tag_ids: post.tag_ids + [tag.id])`, `post.update_attributes!(tag_ids: post.tag_ids - [tag.id])`, or `post.update_attributes!(tag_ids: [])`. These use normal validation, tracking flags, persisted versions and undo/redo. Read fresh IDs before editing if another process may update the association; this is not an atomic concurrent append.

Mongoid's association proxy operations (`post.tags << tag`, `delete`, `clear`, association replacement) and atomic field operations bypass the owner's document update callbacks and are **not tracked**. Calling `save!` afterwards cannot reliably recover those already-persisted changes. This gem deliberately does not override `has_and_belongs_to_many` or install before-add/remove history callbacks: those can record failed operations, misidentify multiple associations to the same class, and lose version updates. For audited membership changes use saved foreign-key assignments rather than proxy operations.

### Set default tracker class name (optional)

For backward compatibility, Mongoid::History uses the first loaded class to include `Mongoid::History::Tracker` as the default history tracker. Explicitly configure the default in a Rails initializer to avoid depending on model loading order, especially with multiple trackers or Rails lazy loading:

```ruby
# config/initializers/mongoid_history.rb
# initializer for mongoid-history
# assuming HistoryTracker is your tracker class
Mongoid::History.tracker_class_name = :history_tracker
```

The initializer is necessary when the tracker has not yet been loaded before the first tracked write. An explicitly configured tracker is constantized on demand, so Rails can autoload it. Without a loaded or configured tracker, tracking raises an `ArgumentError` explaining the required configuration. You can also pass `tracker_class_name:` to `track_history` on individual models.

Namespaced trackers and trackables are supported. Use the fully qualified class name, for example `Mongoid::History.tracker_class_name = 'CMS::HistoryTracker'` or `track_history tracker_class_name: 'CMS::HistoryTracker'`.

### Create trackable classes and objects

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
                  :modifier_field => :modifier, # adds "belongs_to :modifier" to track who made the change, default is :modifier, set to nil to not create modifier_field
                  :modifier_field_inverse_of => :nil, # adds an ":inverse_of" option to the "belongs_to :modifier" relation, default is not set
                  :modifier_field_optional => true, # marks the modifier relationship as optional (requires Mongoid 6 or higher)
                  :version_field => :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                  :track_create  => true,       # track document creation, default is true
                  :track_update  => true,       # track document updates, default is true
                  :track_destroy => true,       # track document destruction, default is true
                  :track_blank_changes => false # track changes from blank? to blank?, default is false
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
post = post.undo! user

# disable tracking for comments within a block
Comment.disable_tracking do
  comment.update_attributes(:title => "Test 3")
end

# disable tracking for comments by default
Comment.disable_tracking!

# enable tracking for comments within a block
Comment.enable_tracking do
  comment.update_attributes(:title => "Test 3")
end

# renable tracking for comments by default
Comment.enable_tracking!

# globally disable all history tracking within a block
Mongoid::History.disable do
  comment.update_attributes(:title => "Test 3")
  user.update_attributes(:name => "Eddie Van Halen")
end

# globally disable all history tracking by default
Mongoid::History.disable!

# globally enable all history tracking within a block
Mongoid::History.enable do
  comment.update_attributes(:title => "Test 3")
  user.update_attributes(:name => "Eddie Van Halen")
end

# globally renable all history tracking by default
Mongoid::History.enable!
```

Undoing destruction returns a newly persisted document with the original identity; the destroyed instance remains destroyed. You can also restore a document with `document.history_tracks.last.undo!(user)`. Pass the acting user to `undo!` and `redo!` so creation and destruction audit entries record that user, including embedded documents.

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

Saving a tracked parent captures changes to permitted fields on its immediate `embeds_one` and `embeds_many` documents, including changes assigned through nested attributes. An `embeds_many` change stores the complete before/after collection, preserving unchanged siblings; tracking never appends duplicate children. Arbitrarily deep embedded changes are not automatically included in the root audit.

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

### Whitelist the tracked attributes of embedded relations

When an embedded model tracks its own history, its own whitelist controls that history's `tracked_changes` and `tracked_edits`; the parent's whitelist only controls the parent's audit. To run embedded history callbacks when saving nested attributes through a parent, configure `cascade_callbacks: true` on the parent's embedded association. This also applies to polymorphic embedded associations. Version counters belong to each tracked document, not to the shared history scope: two children can both have version 1 without changing the parent's counter.

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

### Track all blank changes

Normally changes where both the original and modified values respond with `true` to `blank?` (for example `nil` to `false`) aren't tracked. However, there may be cases where it's important to track such changes, for example when a field isn't present (so appears to be `nil`) then is set to `false`. To track such changes, set the `track_blank_changes` option to `true` (it defaults to `false`) when turning on history tracking:

```ruby
class Book
  include Mongoid::Document
  ...
  field :summary
  track_history # Use default of false for track_blank_changes
end

# summary change not tracked if summary hasn't been set (or has been set to something that responds true to blank?)
Book.find(id).update_attributes(:summary => '')

class Chapter
  include Mongoid::Document
  ...
  field :title
  track_history :track_blank_changes => true
end

# title change tracked even if title hasn't been set
Chapter.find(id).update_attributes(:title => '')
```

### Retrieving the list of tracked static and dynamic fields

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

### Retrieving the list of tracked relations

```ruby
class Book
  ...
  track_history :on => [:pages]
end

Book.tracked_relation?(:pages)    #=> true
Book.tracked_embeds_many          #=> ["pages"]
Book.tracked_embeds_many?(:pages) #=> true
```

### Skip soft-deleted embedded objects with nested tracking

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

### Formatting fields

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

### Displaying history trackers as an audit trail

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

### Assigning the Current Modifier

Without an integration, assign the model's `modifier` explicitly on each change. Setting `Mongoid::History.current_user_method` alone does not discover a controller or enable automatic assignment.

For Rails controllers, opt in to an around-action hook:

```ruby
class ApplicationController < ActionController::Base
  include Mongoid::History::Hooks::Modifier
end

# Optional; defaults to :current_user. Private controller methods are supported.
Mongoid::History.current_user_method = :current_person
```

The hook calls the configured method once for each action and wraps the action in `Mongoid::History.with_modifier`. It does not retain a controller in thread-local storage. Missing methods raise normally rather than silently writing unattributed history.

For Sinatra, background jobs, scripts, or explicit overrides, wrap the entire operation in a block:

```ruby
Mongoid::History.with_modifier(current_user) do
  post.update_attributes!(title: 'Updated')
end
```

The scoped modifier is authoritative: it overrides a previously saved modifier and an assignment within the block. Use a nested `with_modifier(other_user)` to override it, or `with_modifier(nil)` for an anonymous operation. Scopes restore their previous context even after an exception and use RequestStore when available, otherwise thread-local storage. Background work must establish its own scope. No context is installed automatically.

The modifier is assigned before validation and used for create, update, and destroy history. This does not disable model validations: anonymous saves of a required association still fail. Use `modifier_field_optional: true` on Mongoid 6+ when anonymous model saves should be allowed.

### Modifier Names and String Snapshots

`modifier_field: :updater` changes the association on the tracked model, not the shared tracker: use `post.updater` and `post.history_tracks.first.modifier`. A tracker can contain history for multiple models with different association names, so renaming its common `modifier` association per model would be ambiguous and break existing queries. Define an application-specific alias on your tracker if desired.

`modifier_field: nil` omits the model association and produces history without a modifier, including during undo and redo.

The default modifier is a Mongoid association, not a string field. For a durable string snapshot, add a separate field and a callback to your tracker instead of changing the shared association schema:

```ruby
class HistoryTracker
  include Mongoid::History::Tracker
  field :modifier_name, type: String

  before_create do
    self.modifier_name = modifier.name if modifier
  end
end
```

The snapshot survives removal of the referenced user. For an arbitrary label without any user relationship, set `modifier_field: nil` on the model and populate a custom tracker field in a callback from your application's scoped context. Decide which information to retain according to your application's privacy and retention requirements; a snapshot is not automatically exempt from erasure obligations. No userstamp gem is required.

### Setting Modifier Class Name

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

Set `Mongoid::History.modifier_class_name` before loading tracker and trackable classes, because it is used when their associations are declared. Changing `modifier_field` renames the association on a trackable; it does not change the modifier's class.

If your application has no modifier model, use `track_history modifier_field: nil`. This omits the trackable's modifier association and records history with a nil modifier; a `User` model is not required. Setting the global `modifier_class_name` to nil is not how modifier tracking is disabled.

### Repeated declarations and custom version fields

Use `track_history version_field: :_version` to store a trackable's version in `_version` instead of `version`. The default remains `version` for compatibility with existing documents; changing it requires migrating stored version values. History tracker records always use their own `version` field.

Subclasses inherit their parent's tracking options, including `version_field`. Calling `track_history` again on a class or subclass overrides only the supplied options, refreshes the tracked-field configuration, and does not redefine a version field already installed by history tracking. For example, a concern can call `track_history on: :fields, version_field: :_version, modifier_field: nil`, and a model can call `track_history on: :fields` after declaring additional fields. An explicit `on:` replaces the previous field selection rather than appending to it.

### Conditional :if and :unless options

The `track_history` method supports `:if` and `:unless` options which will skip generating
the history tracker unless they are satisfied. These options can take either a method
`Symbol` or a `Proc`. They behave identical to how `:if` and `:unless` behave in Rails model callbacks.

```ruby
  track_history on: [:ip],
                if: :should_i_track_history?,
                unless: ->(obj){ obj.method_to_skip_history }
```

### Using an alternate changes method

Sometimes you may wish to provide an alternate method for determining which changes should be tracked.  For example, if you are using embedded documents
and nested attributes, you may wish to write your own changes method that includes changes from the embedded documents.

Mongoid::History provides an option named `:changes_method` which allows you to do this.  It defaults to `:changes`, which is the standard changes method.

Custom methods must return a Hash of field names to two-element `[original, modified]` Arrays for create and update, matching Mongoid's `changes` contract. Scalar replacements such as `changes.merge(key: "Save history-#{key}")` are invalid. Mongoid uses string field names: use the same string key when overriding an existing change, since `:key` and `"key"` are different Hash keys. Array-valued fields still require an outer change pair, for example `"tags" => [["old"], ["new"]]`. Return `changes` or `{}` when there are no custom changes.

For example, to replace the modified side of a recorded change without losing its original value:

```ruby
def my_changes
  return changes unless changes.key?('key')

  changes.merge('key' => [changes.fetch('key').first, "Save history-#{key}"])
end
```

Custom history values do not change the document during the save, but undo/redo uses those recorded values: redoing the example above can write the prefixed string into the actual field. Keep presentation-only labels out of replayable field values. Destroy tracking snapshots actual attributes rather than calling `:changes_method`; the `:format` option can transform recorded values across create/update/destroy, but likewise affects replay and is not merely display formatting.

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

### Multiple Trackers

You can have different trackers for different classes like so.

``` ruby
class First
  include Mongoid::Document
  include Mongoid::History::Trackable

  field :text, type: String
  track_history on: [:text],
                tracker_class_name: :first_history_tracker
end

class Second
  include Mongoid::Document
  include Mongoid::History::Trackable

  field :text, type: String
  track_history on: [:text],
                tracker_class_name: :second_history_tracker
end

class FirstHistoryTracker
  include Mongoid::History::Tracker
end

class SecondHistoryTracker
  include Mongoid::History::Tracker
end
```

Note that if you are using a tracker for an embedded object that is different
from the parent's tracker, redos and undos will not work. You have to use the
same tracker for these to work across embedded relationships.

If you are using multiple trackers and the `tracker_class_name` parameter is
not specified, Mongoid::History will use the default tracker configured in the
initializer file or whatever the first tracker was loaded.

### Dependent Restrict Associations

When `dependent: :restrict` is used on an association, a call to `destroy` on
the model will raise `Mongoid::Errors::DeleteRestriction` when the dependency
is violated. Just be aware that this gem will create a history track document
before the `destroy` call and then remove if an error is raised. This applies
to all persistence calls: create, update and destroy.

See [spec/integration/validation_failure_spec.rb](spec/integration/validation_failure_spec.rb)
for examples.

### Thread Safety

Mongoid::History stores the tracking enable/disable flag in `Thread.current`.
If the [RequestStore](https://github.com/steveklabnik/request_store) gem is installed, Mongoid::History
will automatically store variables in the `RequestStore.store` instead. RequestStore is recommended
for threaded web servers like Thin or Puma.


## Contributing

You're encouraged to contribute to Mongoid History. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Copyright

Copyright (c) 2011-2024 Aaron Qian and Contributors.

MIT License. See [LICENSE.txt](LICENSE.txt) for further details.
