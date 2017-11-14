### Upgrading to 0.7.0

#### Remove history track when create, update or destroy raises an error

When an error is raised in a call to create, update or destroy a tracked model, any history track
created before the call will now be deleted. In the past this was a problem for associations marked
`dependent: :restrict`.

See [#202](https://github.com/mongoid/mongoid-history/pull/202) for more information.
