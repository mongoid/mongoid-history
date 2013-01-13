Next Release
------------

* [#54](https://github.com/aq1018/mongoid-history/pull/54) Use an index instead of the `$elemMatch` selector in `history_tracks` - [@vecio](https://github.com/vecio).
* [#11](https://github.com/aq1018/mongoid-history/issues/11) Added `:modifier_field_inverse_of` on `track_history` that defines the `:inverse_of` relationship of the modifier class - [@matekb](https://github.com/matekb), [@dblock](https://github.com/dblock).

0.3.1
-----

* [#45](https://github.com/aq1018/mongoid-history/pull/45) Fix: intermittent hash ordering issue with `history_tracks` - [@getaroom](https://github.com/getaroom).
* [#50](https://github.com/aq1018/mongoid-history/pull/50) Fix: tracking of array changes, undo and redo of field changes on non-embedded objects - [@dblock](https://github.com/dblock).

0.3.0 (8/21/2012)
-----------------

* [#41](https://github.com/aq1018/mongoid-history/pull/41) Mongoid 3.x support - [@zambot](https://github.com/zambot).

0.2.4 (8/21/2012)
-----------------

* [#38](https://github.com/aq1018/mongoid-history/pull/38) Fix: allow sub-models to be tracked by using `collection_name` as the scope - [@acant](https://github.com/acant).
* [#35](https://github.com/aq1018/mongoid-history/pull/35) Fix: sweeper references record of change, not the record changed - [@dblock](https://github.com/dblock).

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
