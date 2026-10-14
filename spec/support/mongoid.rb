Mongoid.configure do |config|
  config.connect_to('mongoid_history_test')
  config.around_callbacks_for_embeds = true if config.respond_to?(:around_callbacks_for_embeds=)
  config.prevent_multiple_calls_of_embedded_callbacks = false if config.respond_to?(:prevent_multiple_calls_of_embedded_callbacks=)
end

Mongoid.logger = Logger.new($stdout) if RUBY_ENGINE == 'jruby'

RSpec.configure do |config|
  config.after(:each) do
    Mongoid.purge!
  end

  config.backtrace_exclusion_patterns = [%r{lib/rspec/(core|expectations|matchers|mocks)}]
end
