source "https://rubygems.org"

gemspec

group :test, :console do
  gem "cached_record", :path => "."
  gem "pry"
  gem "mysql2"
  gem "activerecord", :require => "active_record"
  gem "redis"
end

group :test do
  gem "simplecov", :require => false
  gem "data_mapper"
  gem "dm-mysql-adapter"
  gem "dalli"
end