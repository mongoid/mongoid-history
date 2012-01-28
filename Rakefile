require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "mongoid-history"
  gem.homepage = "http://github.com/aq1018/mongoid-history"
  gem.license = "MIT"
  gem.summary = %Q{ history tracking, auditing, undo, redo for mongoid}
  gem.description = %Q{In frustration of Mongoid::Versioning, I created this plugin for tracking historical changes for any document, including embedded ones. It achieves this by storing all history tracks in a single collection that you define. (See Usage for more details) Embedded documents are referenced by storing an association path, which is an array of document_name and document_id fields starting from the top most parent document and down to the embedded document that should track history.

  This plugin implements multi-user undo, which allows users to undo any history change in any order. Undoing a document also creates a new history track. This is great for auditing and preventing vandalism, but it is probably not suitable for use cases such as a wiki.}
  gem.email = ["aq1018@gmail.com", "justin.mgrimes@gmail.com"]
  gem.authors = ["Aaron Qian", "Justin Grimes"]
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.rspec_opts = "--color --format progress"
end

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
