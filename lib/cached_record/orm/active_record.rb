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
        def new_cached_instance(attributes, foreign_keys, variables)
          super.tap do |instance|
            instance.instance_variable_set :@new_record, false
          end
        end
      private
        def set_cached_association(instance, key, value)
          return unless value
          if reflection = _cache_reflection_(instance, key, value)
            value = _cache_value_(instance, reflection, value)
            instance.send :"#{reflection.name}=", value
          end
        end
        def _cache_reflection_(instance, key, value)
          if key.to_s.match /^_(.*)_ids?/
            reflections[$1.pluralize.to_sym]
          else
            instance.send :"#{key}=", value
            reflections.detect{|k, v| v.foreign_key == key.to_s}.try(:last)
          end
        end
        def _cache_value_(instance, reflection, value)
          if value.is_a? Array
            (instance.respond_to?(:association) ? instance.association(reflection.name) : instance.send(reflection.name).instance_variable_get(:@association)).loaded!
            value.collect{|x| reflection.klass.cached x}
          else
            reflection.klass.cached value
          end
        end
      end

      module InstanceMethods
        def cache_attributes
          as_json(cache_json_options.slice(:only).merge(:root => false)).symbolize_keys!.merge cache_foreign_keys
        end
        def cache_foreign_keys
          (cache_json_options[:include] || {}).inject({}) do |json, name|
            reflection = self.class.reflections[name.to_s] || self.class.reflections[name.to_sym]
            json.merge cache_foreign_key(name, reflection, send(name))
          end
        end
        def cache_foreign_key(name, reflection, value)
          case reflection.macro
          when :belongs_to
            {:"#{reflection.foreign_key}" => value.try(:id)}
          when :has_one
            {:"_#{name.to_s.singularize}_id" => value.try(:id)}
          when :has_many, :has_and_belongs_to_many
            {:"_#{name.to_s.singularize}_ids" => value.collect(&:id)}
          end
        end
      end

    end
  end
end