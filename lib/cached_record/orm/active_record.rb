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
        def as_cache_json
          options = cache_json_options

          attributes = {:id => id}.merge! as_json(options.slice(:only, :include)).symbolize_keys!
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