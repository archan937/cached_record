require "gem_ext/redis"
require "cached_record/version"
require "cached_record/cache"
require "cached_record/orm"

module CachedRecord

  def self.setup(*args)
    args.each do |arg|
      if arg.is_a?(Hash)
        arg.each do |store, options|
          Cache.setup store, options
        end
      else
        Cache.setup arg
      end
    end
    ORM::ActiveRecord.setup
    ORM::DataMapper.setup
  end

end