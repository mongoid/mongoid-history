# Releasing Mongoid::History

## Prepare

Use the upstream checkout on a clean `master` and run `git pull --ff-only`. Verify the latest [GitHub Actions](https://github.com/mongoid/mongoid-history/actions) checks pass for supported platforms. Follow semantic versioning: patch for fixes, minor for backward-compatible features, major for breaking changes.

Set `lib/mongoid/history/version.rb` to the release version, date its `CHANGELOG.md` heading using `YYYY/MM/DD`, and remove the contribution placeholder from that section.

```sh
bundle install
bundle exec rake
git add CHANGELOG.md lib/mongoid/history/version.rb RELEASING.md
git commit -m "Preparing for release, 0.9.0."
git push origin master
```

Wait for the preparation commit's CI checks to pass.

## Publish RubyGems and GitHub

```sh
bundle exec rake release
```

This builds the gem, pushes the tag, and publishes to RubyGems. Complete RubyGems MFA when prompted. If interrupted, inspect the existing tag and RubyGems version before retrying. Never move a published tag; if only gem publication is missing, use `gem push pkg/mongoid-history-0.9.0.gem`.

A tag does not create a GitHub release. Once RubyGems publication is verified, create the matching release with the changelog entries as notes:

```sh
version=0.9.0
notes="$(mktemp)"
awk -v version="$version" '
  /^### / {
    if (found) exit
    if ($2 == version) found = 1
    next
  }
  found { print }
' CHANGELOG.md > "$notes"
gh release create "v$version" --repo mongoid/mongoid-history --verify-tag --title "$version" --notes-file "$notes" --latest
rm "$notes"
curl --fail --silent --show-error "https://rubygems.org/api/v2/rubygems/mongoid-history/versions/$version.json"
gh release view "v$version" --repo mongoid/mongoid-history
```

The release is complete only after verifying both RubyGems publication and the non-draft GitHub release.

## Prepare the Next Version

Increment the development patch version in `lib/mongoid/history/version.rb`, for example to `0.9.1`. Add `### 0.9.1 (Next)` and a contribution placeholder above the released section in `CHANGELOG.md`. Commit and push those changes to `master`; leave the released tag unchanged.
