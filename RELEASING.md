# Releasing Mongoid::History

There are no particular rules about when to release Mongoid History.
Release bug fixes frequently, features not so frequently and breaking API changes rarely.

### Release Procedure

Run tests, check that all tests succeed locally.

```
bundle install
bundle exec rake
```

Check that the last build succeeded in [Travis CI](https://travis-ci.org/mongoid/mongoid-history)
for all supported platforms.

Increment the version, modify [lib/mongoid/history/version.rb](lib/mongoid/history/version.rb).
Mongoid History versions should follow [Semantic Versioning (SemVer)](https://semver.org/).

Change "Next Release" in [CHANGELOG.md](CHANGELOG.md) to the new version.

```
### 0.4.0 (2014-01-27)
```

Remove the line with "Your contribution here.", since there will be no more contributions to this release.

Commit your changes.

```
git add CHANGELOG.md lib/mongoid/history/version.rb
git commit -m "Preparing for release, 0.4.0."
git push origin master
```

Release.

```
$ rake release

mongoid-history 0.4.0 built to pkg/mongoid-history-0.4.0.gem.
Tagged v0.4.0.
Pushed git commits and tags.
Pushed mongoid-history 0.4.0 to rubygems.org.
```

### Prepare for the Next Version

Add the next release to [CHANGELOG.md](CHANGELOG.md).

```
### 0.4.1 (Next)

* Your contribution here.
```

Increment the minor version, modify [lib/mongoid/history/version.rb](lib/mongoid/history/version.rb).

Commit your changes.

```
git add CHANGELOG.md lib/mongoid/history/version.rb
git commit -m "Preparing for next release, 0.4.1."
git push origin master
```
