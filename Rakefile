require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/testtask'

task 'default' => ['test']

desc "Run all tests"
task 'test' => ['test:functional']

namespace 'test' do

  functional_tests = FileList['test/functional/**/*_test.rb']

  desc "Run functional tests"
  Rake::TestTask.new('functional') do |t|
    t.libs << 'test'
    t.test_files = functional_tests
    t.verbose = true
  end

  begin
    require 'rcov/rcovtask'
    Rcov::RcovTask.new('coverage') do |t|
      t.libs << 'test'
      t.test_files = functional_tests
      t.verbose = true
      t.rcov_opts << '--sort coverage'
      t.rcov_opts << '--xref'
    end
  rescue LoadError
    desc '"gem install rcov" to enable this'
    task 'coverage' => []
  end
end

desc 'Generate RDoc'
Rake::RDocTask.new('rdoc') do |task|
  task.main = 'README'
  task.title = "Doze"
  task.rdoc_dir = 'doc'
  task.rdoc_files = FileList['lib/**/*.rb'].include('README')
end

desc "Generate all documentation"
task 'generate_docs' => ['clobber_rdoc', 'rdoc']

Gem.manage_gems if Gem::RubyGemsVersion < '1.2.0'

spec = Gem::Specification.new do |s|
  s.name   = "doze"
  s.summary = "RESTful resource-oriented API framework"
  s.version = '0.0.4'
  s.platform = Gem::Platform::RUBY
  s.author = 'Matthew Willson'
  # s.description = ''
  # s.email = ''
  # s.homepage = ''
  # s.rubyforge_project = ''

  s.add_dependency('rack', '~> 1.0')

  s.has_rdoc = true
  s.extra_rdoc_files = ['README']
  s.rdoc_options << '--title' << 'Doze' << '--main' << 'README' << '--line-numbers'
  s.files = FileList['{lib,test}/**/*.rb', '[A-Z]*'].exclude('TODO').to_a
end

Rake::GemPackageTask.new(spec) do |package|
  package.need_zip = true
  package.need_tar = true
end

desc 'Generate gemspec file for github.'
task :update_gemspec do
  File.open('doze.gemspec', 'w') {|output| output << spec.to_ruby}
end
