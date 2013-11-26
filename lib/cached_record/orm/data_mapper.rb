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
        def new_cached_instance(attributes, foreign_keys, variables)
          super.tap do |instance|
            instance.persistence_state = ::DataMapper::Resource::PersistenceState::Clean.new instance
          end
        end
      private
        def set_cached_association(instance, key, value)
          return unless value
          relationship = begin
            if key.to_s.match /^_(.*)_ids?/
              relationships[$1.pluralize.to_sym]
            else
              instance.send :"#{key}=", value
              relationships.detect{|r| r.child_key.first.name.to_s == key.to_s}
            end
          end
          return unless relationship
          value = begin
            if value.is_a? Array
              value.collect{|x| relationship.child_model.cached x}
            elsif relationship.is_a?(::DataMapper::Associations::ManyToOne::Relationship)
              relationship.parent_model.cached value
            end
          end
          instance.instance_variable_set relationship.instance_variable_name, value
        end
      end

      module InstanceMethods
        def cache_attributes
          (cache_json_options[:only] ? as_json.slice(*cache_json_options[:only]) : as_json).symbolize_keys!.merge cache_foreign_keys
        end
        def cache_foreign_keys
          (cache_json_options[:include] || {}).inject({}) do |json, association|
            relationship = relationships[association]
            [value = send(association)].flatten.compact.each{|instance| Cache.set instance}
            case relationship
            when ::DataMapper::Associations::ManyToOne::Relationship
              json[:"#{relationship.child_key.first.name}"] = value.try(:id)
            when ::DataMapper::Associations::OneToOne::Relationship
              json[:"_#{association.to_s.singularize}_id"] = value.try(:id)
            when ::DataMapper::Associations::OneToMany::Relationship, ::DataMapper::Associations::ManyToMany::Relationship
              json[:"_#{association.to_s.singularize}_ids"] = value.collect(&:id)
            end
            json
          end
        end
      end

    end
  end
end