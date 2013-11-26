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
          reflection = begin
            if key.to_s.match /^_(.*)_ids?/
              reflections[$1.pluralize.to_sym]
            else
              instance.send :"#{key}=", value
              reflections.detect{|k, v| v.foreign_key == key.to_s}.try(:last)
            end
          end
          return unless reflection
          value = begin
            if value.is_a? Array
              (instance.respond_to?(:association) ? instance.association(reflection.name) : instance.send(reflection.name).instance_variable_get(:@association)).loaded!
              value.collect{|x| reflection.klass.cached x}
            else
              reflection.klass.cached value
            end
          end
          instance.send :"#{reflection.name}=", value
        end
      end

      module InstanceMethods
        def cache_attributes
          as_json(cache_json_options.slice(:only).merge(:root => false)).symbolize_keys!.merge cache_foreign_keys
        end
        def cache_foreign_keys
          (cache_json_options[:include] || {}).inject({}) do |json, association|
            reflection = self.class.reflections[association]
            [value = send(association)].flatten.compact.each{|instance| Cache.set instance}
            case reflection.macro
            when :belongs_to
              json[:"#{reflection.foreign_key}"] = value.try(:id)
            when :has_one
              json[:"_#{association.to_s.singularize}_id"] = value.try(:id)
            when :has_many, :has_and_belongs_to_many
              json[:"_#{association.to_s.singularize}_ids"] = value.collect(&:id)
            end
            json
          end
        end
      end

    end
  end
end