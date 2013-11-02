require "yaml"

dbconfig = YAML.load_file(File.expand_path("../../config/database.yml", __FILE__))["development"]
ActiveRecord::Base.establish_connection dbconfig
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = :local

CachedRecord.setup { redis }
Redis.new.flushdb

class Article < ActiveRecord::Base
  belongs_to :user
end

class User < ActiveRecord::Base
  has_many :articles
end