# -*- encoding: utf-8 -*-
require File.expand_path("../lib/cached_record/version", __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Paul Engel"]
  gem.email         = ["pm_engel@icloud.com"]
  gem.summary       = %q{Cache (and optionally memoize) ActiveRecord or DataMapper records in Redis or Memcached}
  gem.description   = %q{Cache (and optionally memoize) ActiveRecord or DataMapper records in Redis or Memcached}
  gem.homepage      = "https://github.com/archan937/cached_record"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "cached_record"
  gem.require_paths = ["lib"]
  gem.version       = CachedRecord::VERSION
  gem.licenses      = ["MIT"]

  gem.add_dependency "dalli"
  gem.add_dependency "redis", ">= 3.0.5"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "minitest"
  gem.add_development_dependency "mocha"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "mysql2"
  gem.add_development_dependency "activerecord"
  gem.add_development_dependency "dm-mysql-adapter"
  gem.add_development_dependency "data_mapper"
end
