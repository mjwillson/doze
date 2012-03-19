# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'doze/version'

spec = Gem::Specification.new do |s|
  s.name   = "doze"
  s.summary = "RESTful resource-oriented API framework"
  s.description = 'Library for building restful APIs, with hierarchical routing, content type handling and other RESTful stuff'
  s.version = Doze::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Matthew Willson']
  s.email = ["matthew@playlouder.com"]
  s.homepage = 'https://github.com/mjwillson/doze'

  s.add_development_dependency('rake')
  s.add_development_dependency('rack-test')
  s.add_development_dependency('mocha')

  s.add_dependency('rack', '~> 1.0')
  s.add_dependency('json', '1.5.1')

  s.has_rdoc = true
  s.extra_rdoc_files = ['README']
  s.rdoc_options << '--title' << 'Doze' << '--main' << 'README' << '--line-numbers'
  s.files = Dir["lib/**/*.rb"] + ['README']
  s.test_files = Dir["test/**/*"]
end
