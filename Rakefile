require "rake/testtask"
require 'rake/gempackagetask'

Rake::TestTask.new('test') do |t|
  t.pattern = 'test/tc_*.rb'
  t.libs = [File.expand_path("lib")]
  t.warning = true
end

spec = Gem::Specification.new do |s| 
  s.name = "dataset"
  s.version = "0.5"
  s.author = "Jason May"
  s.email = "jmay@numbrary.com"
  s.homepage = "http://numbrary.com/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Dataset manipulation routines for Numbrary"
  s.files = FileList["{bin,lib}/**/*"].to_a
  s.require_path = "lib"
  s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.has_rdoc = false # please document me
  # s.extra_rdoc_files = ["README"]
  s.add_dependency("fastercsv", ">= 1.2.3")
  s.rubyforge_project = nil # this isn't going out to the world
end
 
Rake::GemPackageTask.new(spec) do |pkg| 
  pkg.need_tar = true 
end
