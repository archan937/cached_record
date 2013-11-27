require "yaml"
require "logger"
require "active_record"

dbconfig = YAML.load_file(File.expand_path("../../config/database.yml", __FILE__))["development"]
logger = Logger.new("log/development.log")

ActiveRecord::Base.establish_connection dbconfig
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = :local
ActiveRecord::Base.logger = logger

CachedRecord.setup :redis
Redis.new.flushdb

class Article < ActiveRecord::Base
  belongs_to :author, :class_name => "User"
  has_many :comments
  has_and_belongs_to_many :tags
  as_memoized_cache :redis, :only => [:title], :include => [:author, :comments, :tags]
end

class User < ActiveRecord::Base
  has_one :foo, :class_name => "Article", :foreign_key => "foo_id"
  as_memoized_cache :redis, :only => [:name], :include => [:foo]
end

class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :poster, :class_name => "User"
  as_memoized_cache :redis, :only => [:content], :include => [:poster]
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :articles
  as_memoized_cache :redis, :only => [:name]
end