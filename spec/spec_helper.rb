require 'rubygems'
require 'spork'

Spork.prefork do
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

  require 'rubygems'
  require 'bundler/setup'

  Bundler.require :default, :test

  Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each do |f| 
    require f
  end
end

Spork.each_run do
  require 'mongoid-history'
end

