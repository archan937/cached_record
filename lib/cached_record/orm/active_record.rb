module CachedRecord
  module ORM
    module ActiveRecord

      def self.setup?
        !!defined?(::ActiveRecord)
      end

      def self.setup
        return false unless setup?
        ::ActiveRecord::Base.send :include, ORM
        ::ActiveRecord::Base.extend ClassMethods
        ::ActiveRecord::Base.send :include, InstanceMethods
        true
      end

      module ClassMethods
        def uncached(id)
          find(id)
        end
      end

      module InstanceMethods
        def cache_attributes
          as_json(cache_json_options.slice(:only, :include)).symbolize_keys!
        end
      end

    end
  end
end