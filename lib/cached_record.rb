require "cached_record/version"
require "cached_record/cache"
require "cached_record/orm"

module CachedRecord

  def self.setup(&block)
    if block_given?
      CachedRecord::Cache.class_eval &block
    end
    CachedRecord::ORM::ActiveRecord.setup
    CachedRecord::ORM::DataMapper.setup
  end

end