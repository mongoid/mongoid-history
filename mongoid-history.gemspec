$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'mongoid/history/version'

Gem::Specification.new do |s|
  s.name        = 'mongoid-history'
  s.version     = Mongoid::History::VERSION
  s.authors     = ['Aaron Qian', 'Justin Grimes', 'Daniel Doubrovkine']
  s.summary     = 'Track and audit, undo and redo changes on Mongoid documents.'
  s.description = 'This library tracks historical changes for any document, including embedded ones. It achieves this by storing all history tracks in a single collection that you define. Embedded documents are referenced by storing an association path, which is an array of document_name and document_id fields starting from the top most parent document and down to the embedded document that should track history. Mongoid-history implements multi-user undo, which allows users to undo any history change in any order. Undoing a document also creates a new history track. This is great for auditing and preventing vandalism, but it is probably not suitable for use cases such as a wiki.'
  s.email       = ['aq1018@gmail.com', 'justin.mgrimes@gmail.com', 'dblock@dblock.org']
  s.homepage    = 'http://github.com/mongoid/mongoid-history'
  s.license     = 'MIT'

  s.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.post_install_message = File.read('UPGRADING') if File.exist?('UPGRADING')

  s.add_runtime_dependency 'easy_diff'
  s.add_runtime_dependency 'mongoid', '>= 3.0'
  s.add_runtime_dependency 'mongoid-compatibility'
  s.add_runtime_dependency 'activesupport'
end
