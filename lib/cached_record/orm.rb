require "cached_record/orm/active_record"
require "cached_record/orm/data_mapper"

module CachedRecord
  module ORM

    def self.included(base)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      def as_cache(*args)
        if args.any?
          store = args.first if args.first.is_a? Symbol
          as_json = args.last if args.last.is_a? Hash
          @as_cache = {
            :store => store,
            :as_json => as_json
          }.reject{|key, value| value.nil?}
        end
        @as_cache ||= {}
      end
      def cache_key(id)
        "#{name.underscore.gsub("/", ".")}.#{id}"
      end
      def cached(id)
        Cache.get(self, id) || begin
          instance = uncached(id)
          Cache.set(instance)
          instance
        end
      end
      def uncached(id)
        raise NotImplementedError, "Cannot fetch uncached `#{self.class}` instances"
      end
      def load_cache_json(json)
        raise NotImplementedError, "Cannot load `#{self.class}` instances from cache JSON"
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