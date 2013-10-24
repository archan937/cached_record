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
        def load_cache_json(json)
          new(json)
        end
      end

      module InstanceMethods
        def as_cache_json
          as_json.inject({}) do |json, (key, value)|
            json[key.to_sym] = value
            json
          end
        end
      end

    end
  end
end