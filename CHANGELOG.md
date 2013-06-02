Next Release
------------

* Your contribution here.
* [API Change] :destroy action now stores trackers in the format original=value, modified=nil (previously it was the reverse) - [@johnnyshields](https://github.com/johnnyshields)
* Support for polymorphic embedded classes - [@tstepp](https://github.com/tstepp)
* Support for Mongoid field aliases, e.g. `field :n, as: :name` - [@johnnyshields](https://github.com/johnnyshields)
* Support for Mongoid embedded aliases, e.g. `embeds_many :comments, store_as: :coms` - [@johnnyshields](https://github.com/johnnyshields)
* Add `#tracked_changes` and `#tracked_edits` methods to `Tracker` class for nicer change summaries - [@johnnyshields](https://github.com/johnnyshields) and [@tstepp](https://github.com/tstepp)
* Refactored and exposed `#trackable_parent_class` in `Tracker`, which returns the class of the trackable regardless of whether the trackable itself has been destroyed - [@johnnyshields](https://github.com/johnnyshields)
* Add class-level `#tracked_field?` and `#tracked_fields` methods; refactor logic to determine whether a field is tracked - [@johnnyshields](https://github.com/johnnyshields)
* Fix bug in Trackable#track_update where `return` condition at beginning of method caused a short-circuit where memoization would not be cleared properly. - [@johnnyshields](https://github.com/johnnyshields)
* Tests: Added spec for nested embedded documents - [@matekb](https://github.com/matekb)
* Tests: Test run time cut in half (~2.5s versus ~5s) by using `#let` helper and removing class initialization before each test - [@johnnyshields](https://github.com/johnnyshields)
* Tests: Remove `database_cleaner` gem in favor of `Mongoid.purge!` - [@johnnyshields](https://github.com/johnnyshields)
* Tests: Remove dependency on non-committed file `mongoid.yml` and hardcode collection to `mongoid_history_test` - [@johnnyshields](https://github.com/johnnyshields)

0.3.3 (4/1/2013)
----------------

* [#42](https://github.com/aq1018/mongoid-history/issues/42) Fix: corrected creation of association chain when using nested embedded documents - [@matekb](https://github.com/matekb).
* [#56](https://github.com/aq1018/mongoid-history/issues/56) Fix: now possible to undo setting (creating) attributes that was previously unset - [@matekb](https://github.com/matekb).
* [#49](https://github.com/aq1018/mongoid-history/issues/49) Fix: now correctly undo/redo localized fields - [@edejong](https://github.com/edejong).


0.3.2 (1/24/2013)
-----------------

* [#54](https://github.com/aq1018/mongoid-history/pull/54) Use an index instead of the `$elemMatch` selector in `history_tracks` - [@vecio](https://github.com/vecio).
* [#11](https://github.com/aq1018/mongoid-history/issues/11) Added `:modifier_field_inverse_of` on `track_history` that defines the `:inverse_of` relationship of the modifier class - [@matekb](https://github.com/matekb), [@dblock](https://github.com/dblock).

0.3.1 (11/16/2012)
------------------

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
