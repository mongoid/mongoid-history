source 'https://rubygems.org'

gemspec

case version = ENV['MONGOID_VERSION'] || '~> 3.1'
when /4/
  gem 'mongoid', github: 'mongoid/mongoid'
when /3/
  gem 'mongoid', '~> 3.1'
else
  gem 'mongoid', version
end
