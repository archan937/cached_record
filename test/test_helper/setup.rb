require "yaml"

dbconfig = YAML.load_file(path("config/database.yml"))["test"]
ActiveRecord::Base.establish_connection dbconfig
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = :local
DataMapper.setup :default, dbconfig.merge("adapter" => "mysql")

cached_record do
  memcached
  redis
end