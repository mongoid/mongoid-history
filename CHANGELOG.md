Next Release
------------

* [#75](http://github.com/aq1018/mongoid-history/pull/75): Add :changes_method option

0.2.4 (8/21/2012)
-----------------

* [#38](https://github.com/aq1018/mongoid-history/pull/38) Fix: Allow sub-models to be tracked by using `collection_name` as the scope - [@acant](https://github.com/acant).
* [#35](https://github.com/aq1018/mongoid-history/pull/35): Fix: sweeper references record of change, not the record changed - [@dblock](https://github.com/dblock).

0.2.3 (4/20/2012)
-----------------

* [#23](https://github.com/aq1018/mongoid-history/pull/34): Updated `Trackable::association_hash` to write through parent - [@tcopple](https://github.com/tcopple).
* Fix: `Trackable::association_hash` nil meta value call - [@tcopple](https://github.com/tcopple).
* [#27](https://github.com/aq1018/mongoid-history/pull/27): Added support for re-creation of destroyed embedded documents - [@erlingwl](https://github.com/erlingwl)

0.1.7 (12/9/2011)
-----------------

* Fix: tracking `false` values - [@gottfrois](https://github.com/gottfrois).
* Use a mongoid observer and controller `around_filter` to pick up modifying user from controller - [@bensymonds](https://github.com/bensymonds).
* More flexible dependency on mongoid - [@sarcilav](https://github.com/sarcilav).
* Fix: tracking broken in a multithreaded environment - [@dblock](https://github.com/dblock).

0.1.0 (5/13/2011)
-----------------

* Added support for `destroy` - [@dblock](https://github.com/dblock).
* Added undo and redo - [@aq1018](https://github.com/aq1018).
* Added support for temporarily disabling history tracking - [@aq1018](https://github.com/aq1018).
* Record modifier for undo and redo actions - [@aq1018](https://github.com/aq1018).

0.0.1 (3/4/2011)
----------------

* Intial public release - [@aq1018](https://github.com/aq1018).
