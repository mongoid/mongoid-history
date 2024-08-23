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

group :development, :test do
  gem 'bundler'
  gem 'pry'
  gem 'rake'
end

group :test do
  gem 'benchmark-ips', require: false
  gem 'coveralls'
  gem 'gem-release'
  gem 'mongoid-danger', '~> 0.1.0', require: false
  gem 'request_store'
  gem 'rspec', '~> 3.1'
  gem 'rubocop', '~> 0.49.0'
  gem 'term-ansicolor', '~> 1.3.0'
  gem 'yard'
end
