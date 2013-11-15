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
        instance_variables, attributes = json.partition{|k, v| k.to_s.match /^@/}.collect{|x| Hash[x]}
        new(attributes).tap do |instance|
          instance_variables.each do |name, value|
            instance.instance_variable_set name, value
          end
        end
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
        {}.tap do |opts|
          opts[:only] = symbolize_array(options[:only]) if options[:only]
          opts[:include] = symbolize_array(options[:include]) if options[:include]
          opts[:memoize] = parse_memoize_options(options[:memoize]) if options[:memoize]
        end
      end

      def symbolize_array(array)
        array.collect &:to_sym
      end

      def parse_memoize_options(options)
        [options].flatten.inject({}) do |memo, x|
          hash = x.is_a?(Hash) ? x : {x => :"@#{x}"}
          memo.merge hash.inject({}){|h, (k, v)| h[k.to_sym] = v.to_sym; h}
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