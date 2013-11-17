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

      def as_memoized_cache(*args)
        as_cache(*args).tap do |options|
          options[:memoize] = true
        end
      end

      def cache_key(id)
        "#{name.underscore.gsub("/", ".")}.#{id}"
      end

      def cache_root
        "#{name.underscore.gsub(/^.*\//, "")}".to_sym
      end

      def cached(id)
        Cache.get(self, id) do
          uncached id
        end
      end

      def uncached(id)
        raise NotImplementedError, "Cannot fetch uncached `#{self.class}` instances"
      end

      def load_cache_json(json)
        json.symbolize_keys!
        if as_cache[:as_json][:include_root]
          attributes = json.delete cache_root
          variables = json.inject({}){|h, (k, v)| h[:"@#{k}"] = v; h}
        else
          variables, attributes = json.partition{|k, v| k.to_s.match /^@/}.collect{|x| Hash[x]}
        end
        new_cached_instance attributes, variables
      end

      def new_cached_instance(attributes, variables)
        new(attributes).tap do |instance|
          variables.each do |name, value|
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
        options.assert_valid_keys :only, :include, :memoize, :include_root
        options.slice(:only, :include).each do |key, value|
          raise ArgumentError unless value.is_a?(Array)
        end
        if options[:memoize] && !options[:memoize].is_a?(Enumerable)
          raise ArgumentError
        end
        if options.include?(:include_root) && ![true, false].include?(options[:include_root])
          raise ArgumentError
        end
      end

      def parse_as_cache_json_options(options)
        {}.tap do |opts|
          opts[:only] = symbolize_array(options[:only]) if options[:only]
          opts[:include] = symbolize_array(options[:include]) if options[:include]
          opts[:memoize] = parse_memoize_options(options[:memoize]) if options[:memoize]
          opts[:include_root] = true if options[:include_root]
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

      def cache_attributes
        raise NotImplementedError, "Cannot return cache attributes for `#{self.class}` instances"
      end

      def as_cache_json
        attributes = {:id => id}.merge cache_attributes
        variables = (cache_json_options[:memoize] || {}).inject({}) do |hash, (method, variable)|
          hash[variable] = send method
          hash
        end
        merge_cache_json attributes, variables
      end

      def merge_cache_json(attributes, variables)
        if cache_json_options[:include_root]
          variables = variables.inject({}){|h, (k, v)| h[k.to_s.gsub(/^@/, "").to_sym] = v; h}
          {self.class.cache_root => attributes}.merge variables
        else
          attributes.merge variables
        end
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