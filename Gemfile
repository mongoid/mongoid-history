source 'https://rubygems.org'

gemspec

case version = ENV['MONGOID_VERSION'] || '~> 6.0.0.beta'
when /6/
  gem 'mongoid', '~> 6.0.0.beta'
when /5/
  gem 'mongoid', '~> 5.0'
when /4/
  gem 'mongoid', '~> 4.0'
when /3/
  gem 'mongoid', '~> 3.1'
else
  gem 'mongoid', version
end
