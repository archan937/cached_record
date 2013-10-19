require "cached_record/orm/active_record"
require "cached_record/orm/data_mapper"

module CachedRecord
  module ORM

    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      def uncached(id)
        raise NotImplementedError, "Cannot fetch uncached `#{self.class}` instances"
      end
    end

    module InstanceMethods
      def as_cache_json
        raise NotImplementedError, "Cannot return cache JSON hash for `#{self.class}` instances"
      end
      def to_cache_json
        as_cache_json.to_json
      end
    end

  end
end