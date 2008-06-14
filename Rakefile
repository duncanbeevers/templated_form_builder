require 'rake/testtask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the templated_form_builder plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end
