$LOAD_PATH.push File.expand_path('../../lib', __FILE__)

require 'mongoid'
require 'mongoid/history'

require 'benchmark/ips'
require './perf/gc_suite'

Mongoid.connect_to('mongoid_history_perf_test')
Mongo::Logger.logger.level = ::Logger::FATAL
Mongoid.purge!

Attributes = Mongoid::History::Attributes

module ZeroPointEight
  class Create < Attributes::Create
    def attributes
      @attributes = {}
      trackable.attributes.each do |k, v|
        next unless trackable_class.tracked_field?(k, :create)
        modified = if changes[k]
                     changes[k].class == Array ? changes[k].last : changes[k]
                   else
                     v
                   end
        @attributes[k] = [nil, format_field(k, modified)]
      end
      insert_embeds_one_changes
      insert_embeds_many_changes
      @attributes
    end
  end
end

class Person
  include Mongoid::Document
  include Mongoid::History::Trackable

  field :first_name, type: String
  field :last_name, type: String
  field :birth_date, type: Date
  field :title, type: String

  track_history on: %i[first_name last_name birth_date]
end

new_person = Person.new(first_name: 'Eliot', last_name: 'Horowitz', birth_date: '1981-05-01', title: 'CTO')

Benchmark.ips do |bm|
  bm.config(suite: GCSuite.new)

  bm.report('HEAD') do
    Attributes::Create.new(new_person).attributes
  end

  bm.report('v0.8.2') do
    ZeroPointEight::Create.new(new_person).attributes
  end

  bm.report('v0.5.0') do
    new_person.attributes.each_with_object({}) { |(k, v), h| h[k] = [nil, v] }.select { |k, _| new_person.class.tracked_field?(k, :create) }
  end

  bm.compare!
end
