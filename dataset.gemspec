# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dataset/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jason W. May"]
  gem.email         = ["jmay@pobox.com"]
  gem.description   = %q{Data manipulation toolkit}
  gem.summary       = %q{Data manipulation toolkit}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "dataset"
  gem.require_paths = ["lib"]
  gem.version       = Dataset::VERSION

  gem.add_dependency 'uuidtools'
  gem.add_dependency 'hpricot'
  gem.add_dependency 'facets'

  gem.add_development_dependency "rake", "~> 0.9.2"
  gem.add_development_dependency "rspec", "~> 2.9.0"
  gem.add_development_dependency "guard-rspec", "~> 0.7.0"
end
