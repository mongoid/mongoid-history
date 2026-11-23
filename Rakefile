require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

Bundler::GemHelper.install_tasks

if RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.3')
  require_relative 'script/release'
  MongoidHistoryRelease.workflow.install_tasks

  %w[release release:rubygem_push release:source_control_push].each do |name|
    Rake::Task[name].clear
    task(name) { abort "#{name} is disabled; releases run through GitHub Actions, see RELEASING.md" }
  end
end

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

task default: %i[rubocop spec]

require 'yard'
YARD::Rake::YardocTask.new
