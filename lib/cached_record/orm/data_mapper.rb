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
        def cache_attributes
          options = cache_json_options
          attributes = as_json options.slice(:include)
          if options[:only]
            keys = options[:only] + (options[:include] || [])
            attributes = attributes.select{|k, v| keys.include? k}
          end
          attributes
        end
      end

    end
  end
end