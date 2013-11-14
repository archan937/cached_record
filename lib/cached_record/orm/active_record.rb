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
          instance_variables, attributes = json.partition{|k, v| k.to_s.match /^@/}.collect{|x| Hash[x]}
          new(attributes).tap do |instance|
            instance_variables.each do |name, value|
              instance.instance_variable_set name, value
            end
          end
        end
      end

      module InstanceMethods
        def as_cache_json
          options = cache_json_options
          {:id => id}.tap do |json|
            json.merge! as_json(options.slice(:only, :include)).symbolize_keys!
            (options[:memoize] || {}).each do |method, variable|
              json[variable] = send method
            end
          end
        end
      end

    end
  end
end