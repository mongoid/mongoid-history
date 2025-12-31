source 'https://rubygems.org'

gemspec

case version = ENV['MONGOID_VERSION'] || '~> 7.0'
when 'HEAD'
  gem 'mongoid', github: 'mongodb/mongoid'
when '7'
  gem 'mongoid', '~> 7.3'
when '7.3'
  gem 'mongoid', '~> 7.3.0'
when '7.2'
  gem 'mongoid', '~> 7.2.0'
when '7.1'
  gem 'mongoid', '~> 7.1.0'
when '7.0'
  gem 'mongoid', '~> 7.0.0'
when '6'
  gem 'mongoid', '~> 6.0'
when '5'
  gem 'mongoid', '~> 5.0'
  gem 'mongoid-observers', '~> 0.2'
when '4'
  gem 'mongoid', '~> 4.0'
  gem 'mongoid-observers', '~> 0.2'
when '3'
  gem 'mongoid', '~> 3.1'
else
  gem 'mongoid', version
end

gem 'mongoid-compatibility'
gem 'psych', '< 5.0'

group :development, :test do
  gem 'bundler'
  gem 'pry'
  gem 'rake'
end

group :test do
  gem 'benchmark-ips', require: false
  gem 'coveralls'
  gem 'danger'
  gem 'danger-changelog'
  gem 'danger-pr-comment'
  gem 'gem-release'
  gem 'racc'
  gem 'request_store'
  gem 'rspec', '~> 3.1'
  gem 'rubocop', '~> 1.28'
  gem 'term-ansicolor', '~> 1.3.0'
  gem 'yard'
end
