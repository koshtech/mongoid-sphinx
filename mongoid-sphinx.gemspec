# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require './lib/mongoid_sphinx/version'

Gem::Specification.new do |s|
  s.name        = 'mongoid-sphinx'
  s.version     = MongoidSphinx::VERSION
  s.authors     = ['Jon Doveston']
  s.platform    = Gem::Platform::RUBY
  s.email       = ['jon@llamadigital.net']
  s.homepage    = ''
  s.summary     = 'A full text indexing extension for MongoDB using Sphinx and Mongoid.'
  s.description = <<-EOF
A full text indexing extension for MongoDB using Sphinx and Mongoid.
This is a fork of a fork of a fork and all due credit goes out to Matt Hodgson and every one else in the chain.
  EOF
  #s.rubyforge_project = 'mongoid-sphinx'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency 'mongoid',       '~> 2.4.0'
  s.add_dependency         'riddle',        '~> 1.5.0'
  s.add_dependency         'activesupport', '~> 3.1.0'

  s.add_development_dependency 'bson_ext',  '~> 1.5.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'rspec',     '>= 2.11.0'
  s.add_development_dependency 'guard',     '>= 1.3.2'
  s.add_development_dependency 'guard-rspec'

  s.add_development_dependency 'libnotify'
  s.add_development_dependency 'rb-inotify'
end

