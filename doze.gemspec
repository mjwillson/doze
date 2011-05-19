# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'doze/version'

spec = Gem::Specification.new do |s|
  s.name   = "doze"
  s.version = Doze::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Matthew Willson']
  s.email = ["matthew@playlouder.com"]
  s.summary = "RESTful resource-oriented API framework"

  s.add_development_dependency('rake')
  s.add_development_dependency('rack-test')
  s.add_development_dependency('mocha')

  s.add_dependency('rack', '~> 1.0')
  s.add_dependency('json', '1.5.1')

  s.files = Dir.glob('{lib,test}/**/*.rb') + ['README']
end
