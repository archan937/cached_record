require "yaml"
require "logger"

dbconfig = YAML.load_file(path("config/database.yml"))["test"]
logger = Logger.new path("log/test.log")

ActiveRecord::Base.establish_connection dbconfig
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = :local
ActiveRecord::Base.logger = logger

DataMapper.setup :default, dbconfig.merge("adapter" => "mysql")
DataMapper.logger = logger

CachedRecord.setup