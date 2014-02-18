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
        @as_cache = parse_as_cache_options args if args.any?
        @as_cache ||= {:as_json => {}}
      end

      def as_memoized_cache(*args)
        retain = args.last.delete(:retain) if args.last.is_a?(Hash)
        as_cache(*args).tap do |options|
          options[:memoize] = true
          options[:retain] = retain if retain
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
        properties, variables = cache_json_to_properties_and_variables(json)
        foreign_keys, attributes = properties.partition{|k, v| k.to_s.match /_ids?$/}.collect{|x| Hash[x]}
        new_cached_instance attributes, foreign_keys, variables
      end

      def new_cached_instance(attributes, foreign_keys, variables)
        id = attributes.delete(:id) || attributes.delete("id")
        _new_cached_instance_(id, attributes).tap do |instance|
          instance.id = id if instance.respond_to?(:id=)
          foreign_keys.each do |key, value|
            set_cached_association instance, key, value
          end
          variables.each do |key, value|
            instance.instance_variable_set key, value
          end
        end
      end

    private

      def _new_cached_instance_(id, attributes)
        new attributes
      end

      def set_cached_association(instance, key, value)
        raise NotImplementedError, "Cannot set cached association for `#{self}` instances"
      end

      def parse_as_cache_options(args)
        if (symbol = args.first).is_a? Symbol
          store = symbol
        end
        if (hash = args.last).is_a? Hash
          expire = hash.delete :expire
          as_json = parse_as_cache_json_options hash
        end
        {
          :store => store,
          :expire => expire,
          :as_json => as_json || {}
        }.reject{|key, value| value.nil?}
      end

      def parse_as_cache_json_options(options)
        options.symbolize_keys!
        validate_as_cache_json_options options
        {}.tap do |opts|
          opts[:only] = symbolize_array(options[:only]) if options[:only]
          opts[:include] = symbolize_array(options[:include]) if options[:include]
          opts[:memoize] = parse_memoize_options(options[:memoize]) if options[:memoize]
          opts[:include_root] = true if options[:include_root]
        end
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

      def symbolize_array(array)
        array.collect &:to_sym
      end

      def parse_memoize_options(options)
        [options].flatten.inject({}) do |memo, x|
          hash = x.is_a?(Hash) ? x : {x => :"@#{x}"}
          memo.merge hash.inject({}){|h, (k, v)| h[k.to_sym] = v.to_sym; h}
        end
      end

      def cache_json_to_properties_and_variables(json)
        if as_cache[:as_json][:include_root]
          properties = json.delete cache_root
          variables = json.inject({}){|h, (k, v)| h[:"@#{k}"] = v; h}
          [properties, variables]
        else
          json.partition{|k, v| !k.to_s.match(/^@/)}.collect{|x| Hash[x]}
        end
      end

    end

    module InstanceMethods

      def cache_attributes
        raise NotImplementedError, "Cannot return cache attributes for `#{self.class}` instances"
      end

      def cache_foreign_keys
        raise NotImplementedError, "Cannot return cache foreign keys for `#{self.class}` instances"
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

      def cache
        Cache.set self
      end

      def expire
        Cache.expire self
      end

    private

      def cache_json_options
        self.class.as_cache[:as_json] || {}
      end

    end

  end
end