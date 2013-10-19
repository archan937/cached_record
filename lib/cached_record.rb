require "cached_record/version"
require "cached_record/orm"

def cached_record(&block)
  CachedRecord::ORM::ActiveRecord.setup
  CachedRecord::ORM::DataMapper.setup
end