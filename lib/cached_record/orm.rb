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
          as_json = parse_as_cache_json_options!(
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

      def parse_as_cache_json_options!(options)
        options = options.symbolize_keys
        validate_as_cache_json_options options
        parse_as_cache_json_options options
      end

      def validate_as_cache_json_options(options)
        options.assert_valid_keys :only, :include, :memoize
        options.slice(:only, :include).each do |key, value|
          raise ArgumentError unless value.is_a?(Array)
        end
        if options[:memoize] && !options[:memoize].is_a?(Enumerable)
          raise ArgumentError
        end
      end

      def parse_as_cache_json_options(options)
        only = options[:only].collect(&:to_sym) if options[:only]
        included = options[:include].collect(&:to_sym) if options[:include]

        memoized = [options[:memoize]].flatten.inject({}) do |memo, x|
          hash = x.is_a?(Hash) ? x : {x => :"@#{x}"}
          memo.merge hash.inject({}){|h, (k, v)| h[k.to_sym] = v.to_sym; h}
        end if options[:memoize]

        {}.tap do |options|
          options[:only] = only if only
          options[:include] = included unless included.blank?
          options[:memoize] = memoized unless memoized.blank?
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