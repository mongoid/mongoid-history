source 'https://rubygems.org'

gemspec

case version = ENV['MONGOID_VERSION'] || '9'
when 'HEAD'
  gem 'mongoid', github: 'mongodb/mongoid'
when '9'
  gem 'mongoid', '~> 9.0'
when '8'
  gem 'mongoid', '~> 8.0'
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
gem 'psych', Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.6') ? '< 4.0' : '< 5.0'

group :development, :test do
  gem 'bundler'
  gem 'pry'
  gem 'rake'
  if RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.3')
    gem 'commonmarker', '~> 2.10', require: false
    gem 'ruby-gem-release', '0.9.0', require: false
  end
end

group :test do
  gem 'base64'
  gem 'benchmark'
  if %w[3 4 5].include?(ENV['MONGOID_VERSION']) && RUBY_ENGINE == 'ruby'
    gem 'bigdecimal', '~> 1.3.5'
  else
    gem 'bigdecimal'
  end
  gem 'benchmark-ips', require: false
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7')
    gem 'danger'
    gem 'danger-changelog'
    gem 'danger-pr-comment'
  end
  gem 'gem-release'
  gem 'logger'
  gem 'mutex_m'
  gem 'racc'
  gem 'request_store'
  gem 'rspec', '~> 3.1'
  gem 'simplecov', Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.5') ? '>= 0.16' : '>= 0.22', require: false
  if RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.3')
    gem 'rubocop', '~> 1.92'
    gem 'rubocop-md', '~> 3.0', require: false
    gem 'rubocop-prose', '~> 0.2', require: false
    gem 'rubocop-rake', '~> 0.7', require: false
    gem 'rubocop-spellcheck', '~> 0.2', require: false
    gem 'rubocop-yaml', '~> 0.1.0', require: false
  end
  gem 'term-ansicolor', '~> 1.3.0'
  gem 'yard'
end
