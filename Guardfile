guard 'rspec', :version => 2, :all_on_start => false, :all_after_pass => false, :cli => "--color --format documentation --drb" do
  watch(%r(^lib/mongoid/history/(.+)\.rb$)) { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r(^spec/.+_spec\.rb$))
end


guard 'spork', :cucumber_env => { 'RAILS_ENV' => 'test' }, :rspec_env => { 'RAILS_ENV' => 'test' } do
  watch('Gemfile')
  watch('Gemfile.lock')
  watch('spec/spec_helper.rb') { :rspec }
end
