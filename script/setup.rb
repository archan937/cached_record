require "yaml"
require "logger"

dbconfig = YAML.load_file(File.expand_path("../../config/database.yml", __FILE__))["development"]
logger = Logger.new("log/development.log")

ActiveRecord::Base.establish_connection dbconfig
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = :local
ActiveRecord::Base.logger = logger

CachedRecord.setup :redis
Redis.new.flushdb

class Article < ActiveRecord::Base
  belongs_to :user
end

class User < ActiveRecord::Base
  has_many :articles
end