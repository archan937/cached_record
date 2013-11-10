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
          as_json = parse_as_cache_json_options(
            args.inject({}){|h, arg| arg.is_a?(Hash) ? h.merge(arg) : h}
          )
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

    private

      def parse_as_cache_json_options(options)
        options = options.symbolize_keys
        options.assert_valid_keys :only, :include
        options.inject({}) do |hash, (key, value)|
          raise ArgumentError unless value.is_a?(Array)
          hash[key] = value.collect(&:to_sym)
          hash
        end
      end

    end

    module InstanceMethods

      def as_cache_json
        raise NotImplementedError, "Cannot return cache JSON hash for `#{self.class}` instances"
      end

      def to_cache_json
        as_cache_json.to_json
      end

    private

      def cache_json_options
        self.class.as_cache[:as_json] || {}
      end

    end

  end
end