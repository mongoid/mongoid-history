# Contributing to Mongoid-History

Mongoid-History is the work of [many contributors](https://github.com/mongoid/mongoid-history/graphs/contributors). You're encouraged to submit [pull requests](https://github.com/mongoid/mongoid-history/pulls), [propose features, ask questions and discuss issues](https://github.com/mongoid/mongoid-history/issues).

## Fork the Project

Fork the [project on GitHub](https://github.com/mongoid/mongoid-history) and check out your copy.

```sh
git clone https://github.com/contributor/mongoid-history.git
cd mongoid-history
git remote add upstream https://github.com/mongoid/mongoid-history.git
```

## Create a Topic Branch

Make sure your fork is up-to-date and create a topic branch for your feature or bug fix.

```sh
git checkout master
git pull upstream master
git checkout -b my-feature-branch
```

## Bundle Install and Test

Ensure that you can build the project and run tests.

```sh
bundle install
bundle exec rake
```

## Write Tests

Try to write a test that reproduces the problem you're trying to fix or describes a feature that you want to build. Add unit specs to [spec/unit](spec/unit) and integration specs to [spec/integration](spec/integration). Specs need a MongoDB server on `localhost:27017`.

We definitely appreciate pull requests that highlight or reproduce a problem, even without a fix.

## Write Code

Implement your feature or bug fix.

Ruby, Markdown, YAML, and spelling are checked with [RuboCop](https://github.com/rubocop/rubocop), [rubocop-md](https://github.com/rubocop/rubocop-md), [rubocop-prose](https://github.com/dblock/rubocop-prose), [rubocop-yaml](https://github.com/dblock/rubocop-yaml), and [rubocop-spellcheck](https://github.com/dblock/rubocop-spellcheck). Run `bundle exec rake lint` on Ruby 3.3 or newer, review any `bundle exec rubocop -a` corrections, and add legitimate new words to [.spellcheck.txt](.spellcheck.txt). Keep each Markdown paragraph on one line and use title case for headings.

Make sure that `bundle exec rake` completes without errors. It runs specs, and lint on Ruby 3.3 or newer.

## Write Documentation

Document any external behavior in the [README](README.md).

## Update Changelog

Add a line to [CHANGELOG](CHANGELOG.md) under the `(Next)` heading. Make it look like every other line, including your name and link to your GitHub account.

## Commit Changes

Make sure git knows your name and email address:

```sh
git config --global user.name "Your Name"
git config --global user.email "contributor@example.com"
```

Writing good commit logs is important. A commit log should describe what changed and why.

```sh
git add ...
git commit
```

## Push

```sh
git push origin my-feature-branch
```

## Make a Pull Request

Go to https://github.com/contributor/mongoid-history and select your feature branch. Click the 'Pull Request' button and fill out the form. Pull requests are usually reviewed within a few days.

## Rebase

If you've been working on a change for a while, rebase with upstream/master.

```sh
git fetch upstream
git rebase upstream/master
git push origin my-feature-branch -f
```

## Update CHANGELOG Again

Update the [CHANGELOG](CHANGELOG.md) with the pull request number. A typical entry looks as follows.

```markdown
* [#123](https://github.com/mongoid/mongoid-history/pull/123): Reticulated splines - [@contributor](https://github.com/contributor).
```

Amend your previous commit and force push the changes.

```sh
git commit --amend
git push origin my-feature-branch -f
```

## Check on Your Pull Request

Go back to your pull request after a few minutes and see whether it passed [GitHub Actions](https://github.com/mongoid/mongoid-history/actions). Everything should look green, otherwise fix issues and amend your commit as described above.

## Be Patient

It's likely that your change will not be merged and that the nitpicky maintainers will ask you to do more, or fix seemingly benign problems. Hang on there!

## Releases

See [RELEASING.md](RELEASING.md).

## Thank You

Please do know that we really appreciate and value your time and work. We love you, really.
