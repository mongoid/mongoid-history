# Upgrading to 1.0

## Tracker snapshots now return typed values

In 1.0, `tracker.original` and `tracker.modified` return copies of the recorded values converted through the tracked model's current Mongoid field definitions. Custom types such as Money and Date therefore return application-level values instead of their serialized database representations. `tracked_changes`, `tracked_edits`, and `affected` also return typed values.

Use `tracker.database_original` and `tracker.database_modified` when you need the serialized snapshots previously returned by `original` and `modified`, such as when inspecting the stored history representation. `tracker.attributes`, bracket access, persisted fields, and database queries remain unchanged. Undo, redo, and restoration continue to use the serialized snapshots internally; reading typed values does not modify stored history.

Typed readers require the tracked model class and its current field definitions to remain available. If a model is removed, a field type changes, or a `:format` transformation loses information, Mongoid History cannot reconstruct the original application value. The explicit `database_*` readers remain available for raw inspection.

See [PR #265](https://github.com/mongoid/mongoid-history/pull/265) for the implementation and examples.

## Upgrading to 0.8.0

### History is now tracked on create and destroy by default

By default, Mongoid History will now track all actions (create, update, and destroy.)
Previously, only update actions were tracked by default.

To preserve the old behavior, please modify your call to `track_history` as follows:

```ruby
  track_history ...
                track_create: false,
                track_destroy: false
```

See [#207](https://github.com/mongoid/mongoid-history/pull/207) for more information.

## Upgrading to 0.7.0

### Remove history track when create, update or destroy raises an error

When an error is raised in a call to create, update or destroy a tracked model, any history track
created before the call will now be deleted. In the past this was a problem for associations marked
`dependent: :restrict`.

See [#202](https://github.com/mongoid/mongoid-history/pull/202) for more information.

## Main Changes / Upgrading Notes

See [#189](https://github.com/mongoid/mongoid-history/pull/189) for more information.

* Currently, the `:all` option behaves identically to `:fields`. Future versions will track all fields and relations of trackable class when using `:all`.

## Upgrading to 0.4.1

### Migrate Userstamp

`Mongoid::History` no longer supports the userstamp natively. To track the User in the application who created the HistoryTracker, add the [Mongoid::Userstamp gem](https://github.com/tbpro/mongoid_userstamp) to your HistoryTracker class.

```ruby
class MyHistoryTracker
  include Mongoid::History::Tracker
  include Mongoid::Userstamp
end
```

Rename the field.

```ruby
MyHistoryTracker.all.rename(modifier_id: :created_by)
```
