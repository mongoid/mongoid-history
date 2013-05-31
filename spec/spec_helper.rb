$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'bundler/setup'

Bundler.require :default, :test

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'mongoid-history'

