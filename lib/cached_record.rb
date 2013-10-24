require "cached_record/version"
require "cached_record/cache"
require "cached_record/orm"

def cached_record(&block)
  if block_given?
    CachedRecord::Cache.class_eval &block
  end
  unless CachedRecord::Cache.setup?
    raise CachedRecord::Cache::Error, "Specify at least one cache store (either Redis or Memcached)"
  end
  CachedRecord::ORM::ActiveRecord.setup
  CachedRecord::ORM::DataMapper.setup
end