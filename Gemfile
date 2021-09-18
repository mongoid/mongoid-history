source 'https://rubygems.org'

gemspec

case version = ENV['MONGOID_VERSION'] || '~> 7.0'
when 'HEAD'
  gem 'mongoid', github: 'mongodb/mongoid'
when /\b7/
  gem 'mongoid', '~> 7.0'
when /\b6/
  gem 'mongoid', '~> 6.0'
when /\b5/
  gem 'mongoid', '~> 5.0'
  gem 'mongoid-observers', '~> 0.2'
when /\b4/
  gem 'mongoid', '~> 4.0'
  gem 'mongoid-observers', '~> 0.2'
when /\b3/
  gem 'mongoid', '~> 3.1'
else
  gem 'mongoid', version
end

gem 'mongoid-compatibility'

group :development, :test do
  gem 'bundler'
  gem 'pry'
  gem 'rake', '< 11.0'
end

group :test do
  gem 'benchmark-ips', require: false
  gem 'coveralls'
  gem 'gem-release'
  gem 'mongoid-danger', '~> 0.1.0', require: false
  gem 'request_store'
  gem 'rspec', '~> 3.1'
  gem 'rubocop', '0.48.1'
  gem 'yard'
end
