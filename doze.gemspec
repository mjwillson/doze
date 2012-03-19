# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'doze/version'

spec = Gem::Specification.new do |s|
  s.name   = "doze"
  s.summary = "RESTful resource-oriented API framework"
  s.version = Doze::VERSION
  s.platform = Gem::Platform::RUBY
  s.author = 'Matthew Willson'
  s.description = 'Library for building restful APIs, with hierarchical routing, content type handling and other RESTful stuff'
  s.email = 'matthew.willson@gmail.com'
  s.homepage = 'https://github.com/mjwillson/doze'

  s.add_dependency('rack', '~> 1.0')

  s.has_rdoc = true
  s.extra_rdoc_files = ['README']
  s.rdoc_options << '--title' << 'Doze' << '--main' << 'README' << '--line-numbers'
  s.files = Dir["lib/**/*.rb"] + ['README']
  s.test_files = Dir["test/**/*"]
end
