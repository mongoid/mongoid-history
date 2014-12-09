require 'easy_diff'

require 'mongoid/history'
require 'mongoid/history/version'
require 'mongoid/history/mongoid'
require 'mongoid/history/tracker'
require 'mongoid/history/trackable'

Mongoid::History.modifier_class_name = 'User'
Mongoid::History.trackable_class_options = {}
Mongoid::History.current_user_method ||= :current_user
