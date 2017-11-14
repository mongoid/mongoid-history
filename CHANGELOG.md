Next Release
============

* Your contribution here.

### 0.7.0 (2017/11/14)

* [#202](https://github.com/mongoid/mongoid-history/pull/202): Do not create tracker on persistence error - [@mikwat](https://github.com/mikwat).
* [#196](https://github.com/mongoid/mongoid-history/pull/196): Fix bug causing history tracks to get mixed up between multiple trackers when using multiple trackers - [@ojbucao](https://github.com/ojbucao).

### 0.6.1 (2017/01/04)

* [#182](https://github.com/mongoid/mongoid-history/pull/182): No-op on repeated calls to destroy - [@msaffitz](https://github.com/msaffitz).
* [#170](https://github.com/mongoid/mongoid-history/pull/170): Parent repo is now [mongoid/mongoid-history](https://github.com/mongoid/mongoid-history) - [@dblock](https://github.com/dblock).
* [#171](https://github.com/mongoid/mongoid-history/pull/171): Add field formatting - [@jnfeinstein](https://github.com/jnfeinstein).
* [#172](https://github.com/mongoid/mongoid-history/pull/172): Add config helper to track all embedded relations - [@jnfeinstein](https://github.com/jnfeinstein).
* [#173](https://github.com/mongoid/mongoid-history/pull/173): Compatible with mongoid 6 - [@sivagollapalli](https://github.com/sivagollapalli).

### 0.6.0 (2016/09/13)

* [#2](https://github.com/dblock/mongoid-history/pull/2): Forked into the [mongoid](https://github.com/mongoid) organization - [@dblock](https://github.com/dblock).
* [#1](https://github.com/dblock/mongoid-history/pull/1): Added Danger, PR linter - [@dblock](https://github.com/dblock).
* [#166](https://github.com/mongoid/mongoid-history/pull/166): Hash fields should default to an empty Hash - [@johnnyshields](https://github.com/johnnyshields).
* [#162](https://github.com/mongoid/mongoid-history/pull/162): Do not consider embedded relations as dynamic fields - [@JagdeepSingh](https://github.com/JagdeepSingh).
* [#144](https://github.com/mongoid/mongoid-history/pull/158): Can modify history tracker insertion on object creation - [@sivagollapalli](https://github.com/sivagollapalli).
* [#155](https://github.com/mongoid/mongoid-history/pull/155): Add support to whitelist the attributes for tracked embeds_one and embeds_many relations - [@JagdeepSingh](https://github.com/JagdeepSingh).
* [#154](https://github.com/mongoid/mongoid-history/pull/154): Prevent soft-deleted embedded documents from tracking - [@JagdeepSingh](https://github.com/JagdeepSingh).
* [#151](https://github.com/mongoid/mongoid-history/pull/151): Added ability to customize tracker class for each trackable; multiple trackers across the app are now possible - [@JagdeepSingh](https://github.com/JagdeepSingh).
* [#151](https://github.com/mongoid/mongoid-history/pull/151): Added automatic support for `request_store` gem as drop-in replacement for `Thread.current` - [@JagdeepSingh](https://github.com/JagdeepSingh).
* [#150](https://github.com/mongoid/mongoid-history/pull/150): Added support for keeping embedded objects audit history in parent itself - [@JagdeepSingh](https://github.com/JagdeepSingh).

### 0.5.0 (2015/09/18)

* [#143](https://github.com/mongoid/mongoid-history/pull/143): Added support for Mongoid 5 - [@dblock](https://github.com/dblock).
* [#133](https://github.com/mongoid/mongoid-history/pull/133): Added dynamic attributes tracking (Mongoid::Attributes::Dynamic) - [@minisai](https://github.com/minisai).
* [#142](https://github.com/mongoid/mongoid-history/pull/142): Allow non-database fields to be specified in conjunction with a custom changes method - [@kayakyakr](https://github.com/kayakyakr).

### 0.4.7 (2015/04/06)

* [#124](https://github.com/mongoid/mongoid-history/pull/124): You can require both `mongoid-history` and `mongoid/history` - [@dblock](https://github.com/dblock).

### 0.4.5 (2015/02/09)

* [#131](https://github.com/mongoid/mongoid-history/pull/131): Added `undo` method, that helps to get specific version of an object without saving changes - [@alexkravets](https://github.com/alexkravets).
* [#127](https://github.com/mongoid/mongoid-history/pull/127): Fixed gem naming per [rubygems](http://guides.rubygems.org/name-your-gem/) specs, now you can `require 'mongoid/history'` - [@nofxx](https://github.com/nofxx).
* [#129](https://github.com/mongoid/mongoid-history/pull/129): Support multiple levels of embedded polimorphic documents - [@BrunoChauvet](https://github.com/BrunoChauvet).
* [#123](https://github.com/mongoid/mongoid-history/pull/123): Used a method compatible with mongoid-observers to determinine the version of Mongoid - [@zeitnot](https://github.com/zeitnot).

### 0.4.4 (2014/7/29)

* [#111](https://github.com/mongoid/mongoid-history/pull/111): Fixed compatibility of `undo!` and `redo!` methods with Rails 3.x - [@mrjlynch](https://github.com/mrjlynch).

### 0.4.3 (2014/07/10)

* [#110](https://github.com/mongoid/mongoid-history/pull/110): Fixed scope reference on history tracks criteria - [@adbeelitamar](https://github.com/adbeelitamar).

### 0.4.2 (2014/07/01)

* [#106](https://github.com/mongoid/mongoid-history/pull/106): Added support for polymorphic relationship `scope` - [@adbeelitamar](https://github.com/adbeelitamar).
* [#106](https://github.com/mongoid/mongoid-history/pull/106): Enabled specifying an array of relationships in `scope` - [@adbeelitamar](https://github.com/adbeelitamar).
* [#83](https://github.com/mongoid/mongoid-history/pull/83): Added support for Mongoid 4.x, which removed `attr_accessible` in favor of protected attributes - [@dblock](https://github.com/dblock).
* [#103](https://github.com/mongoid/mongoid-history/pull/103): Fixed compatibility with models using `default_scope` - [@mrjlynch](https://github.com/mrjlynch).

### 0.4.1 (2014/01/11)

* Fixed compatibility with Mongoid 4.x - [@dblock](https://github.com/dblock).
* `Mongoid::History::Sweeper` has been removed, in accorance with Mongoid 4.x (see [#3108](https://github.com/mongoid/mongoid/issues/3108)) and Rails 4.x observer deprecation - [@dblock](https://github.com/dblock).
* Default modifier parameter to `nil` in `undo!` and `redo!` - [@dblock](https://github.com/dblock).
* Fixed `undo!` and `redo!` for mass-assignment protected attributes - [@mati0090](https://github.com/mati0090).
* Implemented Rubocop, Ruby style linter - [@dblock](https://github.com/dblock).
* Remove unneeded coma from README - [@matsprea](https://github.com/matsprea).
* Replace Jeweler with Gem-Release - [@johnnyshields](https://github.com/johnnyshields).
* Track version as a Ruby file - [@johnnyshields](https://github.com/johnnyshields).

### 0.4.0 (2013/06/12)

* Added `Mongoid::History.disable` and `Mongoid::History.enabled?` methods for global tracking disablement - [@johnnyshields](https://github.com/johnnyshields).
* Added `:changes_method` that optionally overrides which method to call to collect changes - [@joelnordel](https://github.com/joelnordell).
* The `:destroy` action now stores trackers in the format `original=value, modified=nil` (previously it was the reverse) - [@johnnyshields](https://github.com/johnnyshields).
* Support for polymorphic embedded classes - [@tstepp](https://github.com/tstepp).
* Support for Mongoid field aliases, e.g. `field :n, as: :name` - [@johnnyshields](https://github.com/johnnyshields).
* Support for Mongoid embedded aliases, e.g. `embeds_many :comments, store_as: :coms` - [@johnnyshields](https://github.com/johnnyshields).
* Added `#tracked_changes` and `#tracked_edits` methods to `Tracker` class for nicer change summaries - [@johnnyshields](https://github.com/johnnyshields) and [@tstepp](https://github.com/tstepp).
* Refactored and exposed `#trackable_parent_class` in `Tracker`, which returns the class of the trackable regardless of whether the trackable itself has been destroyed - [@johnnyshields](https://github.com/johnnyshields).
* Added class-level `#tracked_field?` and `#tracked_fields` methods; refactor logic to determine whether a field is tracked - [@johnnyshields](https://github.com/johnnyshields).
* Fixed bug in Trackable#track_update where `return` condition at beginning of method caused a short-circuit where memoization would not be cleared properly - [@johnnyshields](https://github.com/johnnyshields).
* Tests: Added spec for nested embedded documents - [@matekb](https://github.com/matekb).
* Tests: Test run time cut in half (~2.5s versus ~5s) by using `#let` helper and removing class initialization before each test - [@johnnyshields](https://github.com/johnnyshields).
* Tests: Remove `database_cleaner` gem in favor of `Mongoid.purge!` - [@johnnyshields](https://github.com/johnnyshields).
* Tests: Remove dependency on non-committed file `mongoid.yml` and hardcode collection to `mongoid_history_test` - [@johnnyshields](https://github.com/johnnyshields).

### 0.3.3 (2013/04/01)

* [#42](https://github.com/mongoid/mongoid-history/issues/42): Fix: corrected creation of association chain when using nested embedded documents - [@matekb](https://github.com/matekb).
* [#56](https://github.com/mongoid/mongoid-history/issues/56): Fix: now possible to undo setting (creating) attributes that was previously unset - [@matekb](https://github.com/matekb).
* [#49](https://github.com/mongoid/mongoid-history/issues/49): Fix: now correctly undo/redo localized fields - [@edejong](https://github.com/edejong).


### 0.3.2 (2013/01/24)

* [#54](https://github.com/mongoid/mongoid-history/pull/54): Used an index instead of the `$elemMatch` selector in `history_tracks` - [@vecio](https://github.com/vecio).
* [#11](https://github.com/mongoid/mongoid-history/issues/11): Added `:modifier_field_inverse_of` on `track_history` that defines the `:inverse_of` relationship of the modifier class - [@matekb](https://github.com/matekb), [@dblock](https://github.com/dblock).

### 0.3.1 (2012/11/16)

* [#45](https://github.com/mongoid/mongoid-history/pull/45): Fix: intermittent hash ordering issue with `history_tracks` - [@getaroom](https://github.com/getaroom).
* [#50](https://github.com/mongoid/mongoid-history/pull/50): Fix: tracking of array changes, undo and redo of field changes on non-embedded objects - [@dblock](https://github.com/dblock).

### 0.3.0 (2012/08/21)

* [#41](https://github.com/mongoid/mongoid-history/pull/41): Mongoid 3.x support - [@zambot](https://github.com/zambot).

### 0.2.4 (2012/08/21)

* [#38](https://github.com/mongoid/mongoid-history/pull/38): Fix: allow sub-models to be tracked by using `collection_name` as the scope - [@acant](https://github.com/acant).
* [#35](https://github.com/mongoid/mongoid-history/pull/35): Fix: sweeper references record of change, not the record changed - [@dblock](https://github.com/dblock).

### 0.2.3 (2012/04/20)

* [#23](https://github.com/mongoid/mongoid-history/pull/34): Updated `Trackable::association_hash` to write through parent - [@tcopple](https://github.com/tcopple).
* Fix: `Trackable::association_hash` nil meta value call - [@tcopple](https://github.com/tcopple).
* [#27](https://github.com/mongoid/mongoid-history/pull/27): Added support for re-creation of destroyed embedded documents - [@erlingwl](https://github.com/erlingwl).

### 0.1.7 (2011/12/09)

* Fix: tracking `false` values - [@gottfrois](https://github.com/gottfrois).
* Used a mongoid observer and controller `around_filter` to pick up modifying user from controller - [@bensymonds](https://github.com/bensymonds).
* More flexible dependency on mongoid - [@sarcilav](https://github.com/sarcilav).
* Fix: tracking broken in a multithreaded environment - [@dblock](https://github.com/dblock).

### 0.1.0 (2011/05/13)

* Added support for `destroy` - [@dblock](https://github.com/dblock).
* Added undo and redo - [@aq1018](https://github.com/aq1018).
* Added support for temporarily disabling history tracking - [@aq1018](https://github.com/aq1018).
* Record modifier for undo and redo actions - [@aq1018](https://github.com/aq1018).

### 0.0.1 (2011/03/04)

* Intial public release - [@aq1018](https://github.com/aq1018).
