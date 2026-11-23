# Releasing Mongoid::History

Releases use [ruby-gem-release](https://github.com/dblock/ruby-gem-release) 0.9.0 through a manually dispatched [Release workflow](.github/workflows/release.yml). Keep the `ruby-gem-release` gem in [Gemfile](Gemfile) and the reusable workflow in `release.yml` pinned to the same version. The workflow publishes through RubyGems Trusted Publishing, so no RubyGems API key or one-time password is needed. It only runs from `master` in `mongoid/mongoid-history`.

The local Bundler `rake release`, `release:rubygem_push`, and `release:source_control_push` tasks are disabled so that releases only happen through the workflow.

## One-Time Setup

Before the first automated release, a maintainer must:

1. Create the GitHub environment `release` in `mongoid/mongoid-history`, for example with `gh api --method PUT repos/mongoid/mongoid-history/environments/release`, and restrict its deployment branches to `master`. Add required reviewers to the environment to require maintainer approval before publication.
2. At [mongoid-history's trusted publishers](https://rubygems.org/gems/mongoid-history/trusted_publishers), add a GitHub Actions publisher with repository owner `mongoid`, repository `mongoid-history`, workflow filename `release.yml`, environment `release`, and the separate workflow repository owner `dblock` and repository `ruby-gem-release`.
3. Allow GitHub Actions to push release commits and `v*` tags to `master`. The workflow uses `GITHUB_TOKEN` with `contents: write` and `id-token: write`, and pushes the release commit and the next development version directly to `master`. See the upstream [setup and permissions guidance](https://github.com/dblock/ruby-gem-release/blob/v0.9.0/RELEASING.md#one-time-setup).

Installing the workflow does not apply these settings. To verify them without publishing, run a [dry run](https://github.com/dblock/ruby-gem-release/blob/v0.9.0/docs/actions/release.md#dry-run).

## Prepare

Start with a clean, up-to-date `master`, and verify that the latest [CI checks](https://github.com/mongoid/mongoid-history/actions) pass for all supported Ruby, Mongoid, and MongoDB versions. Review [CHANGELOG.md](CHANGELOG.md) and [UPGRADING.md](UPGRADING.md).

Follow semantic versioning: patch for fixes, minor for backward-compatible features, major for breaking changes. Check `Mongoid::History::VERSION` in [lib/mongoid/history/version.rb](lib/mongoid/history/version.rb), and the matching `### x.y.z (Next)` heading in [CHANGELOG.md](CHANGELOG.md). Change both in a pull request, or pass a `version` override when dispatching.

Keep the `(Next)` heading and the `* Your contribution here.` placeholder. The workflow dates the heading using `YYYY/MM/DD` and removes the placeholder. A section with only the placeholder cannot be released.

Release automation requires MRI Ruby 3.3 or newer; the release dependency and tasks are skipped on older Ruby versions and JRuby. Release specs in [spec/release](spec/release) run the actual release tasks against a local fixture, using the [ruby-gem-release RSpec helpers](https://github.com/dblock/ruby-gem-release/blob/v0.9.0/docs/testing.md), without contacting RubyGems or GitHub.

```sh
bundle install
bundle exec rake
```

## Publish

Dispatch the checked-in version:

```sh
gh workflow run release.yml --repo mongoid/mongoid-history --ref master
```

To release a different version, pass an override:

```sh
gh workflow run release.yml --repo mongoid/mongoid-history --ref master -f version=1.0.0
```

Dispatching starts a real release, not a dry run. Do not merge into `master` while a release runs.

The workflow prepares the release commit, starts MongoDB 8.0, runs RuboCop and specs with Mongoid 9 on Ruby 3.3, builds the gem, preserves recovery artifacts, publishes to RubyGems, pushes the release commit and `v` tag, and creates a GitHub Release with the changelog notes and the gem attached. It then increments the patch version, adds a new `(Next)` section with the placeholder, and pushes the next development commit to `master`. For a planned minor or major next version, change it in a later pull request.

Verify the published version on [RubyGems](https://rubygems.org/gems/mongoid-history), the tag, the [GitHub Release](https://github.com/mongoid/mongoid-history/releases), and the next development commit. The workflow does not replace the full CI matrix.

## Recover a Partial Release

Inspect the failed run, RubyGems, remote commits and tags, and the GitHub Release before retrying. Publication may have succeeded even if a later Git push or next development commit failed. Never move a published tag or republish a version with different contents.

Use the run's retained recovery artifacts and the upstream [recovery instructions](https://github.com/dblock/ruby-gem-release/blob/v0.9.0/docs/actions/release.md#recovery-artifacts) to finish the release with the exact prepared commit and gem.
