module CachedRecord
  module ORM
    module DataMapper

      def self.setup?
        !!defined?(::DataMapper)
      end

      def self.setup
        return false unless setup?
        ::DataMapper::Resource.class_eval do
          class << self
            alias :included_without_cached_record :included
          end
          def self.included(base)
            included_without_cached_record base
            base.extend ORM::ClassMethods
            base.extend ClassMethods
          end
        end
        ::DataMapper::Resource.send :include, ORM::InstanceMethods
        ::DataMapper::Resource.send :include, InstanceMethods
        true
      end

      module ClassMethods
        def uncached(id)
          get(id)
        end
      end

      module InstanceMethods
        def as_cache_json
          options = cache_json_options

          attributes = as_json options.slice(:include)
          if options[:only]
            keys = options[:only] + (options[:include] || [])
            attributes = attributes.select{|k, v| keys.include? k}
          end

          attributes = {:id => id}.merge! attributes
          variables = (options[:memoize] || {}).inject({}) do |hash, (method, variable)|
            hash[variable] = send method
            hash
          end

          if options[:include_root]
            variables = variables.inject({}){|h, (k, v)| h[k.to_s.gsub(/^@/, "").to_sym] = v; h}
            {self.class.cache_root => attributes}.merge! variables
          else
            attributes.merge! variables
          end
        end
      end

    end
  end
end