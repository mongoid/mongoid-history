## Upgrading Mongoid History

### Upgrading to 0.8.0

#### History is now tracked on create and destroy by default

By default, Mongoid History will now track all actions (create, update, and destroy.)
Previously, only update actions were tracked by default.

To preserve the old behavior, please modify your call to `track_history` as follows:

```ruby
  track_history ...
                track_create: false,
                track_destroy: false
```

See [#207](https://github.com/mongoid/mongoid-history/pull/207) for more information.

### Upgrading to 0.7.0

#### Remove history track when create, update or destroy raises an error

When an error is raised in a call to create, update or destroy a tracked model, any history track
created before the call will now be deleted. In the past this was a problem for associations marked
`dependent: :restrict`.

See [#202](https://github.com/mongoid/mongoid-history/pull/202) for more information.
