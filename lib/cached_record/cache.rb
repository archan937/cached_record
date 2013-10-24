module CachedRecord
  module Cache
    class Error < StandardError; end

    def self.setup?
      stores.any?
    end

    def self.memcached(options = nil)
      if stores[:memcached].nil? || options
        options ||= {}
        host = options.delete(:host) || "localhost"
        port = options.delete(:port) || 11211
        stores[:memcached] = Dalli::Client.new "#{host}:#{port}", options
      end
      stores[:memcached]
    end

    def self.redis(options = nil)
      if stores[:redis].nil? || options
        options ||= {}
        stores[:redis] = Redis.new options
      end
      stores[:redis]
    end

    def self.store(klass)
      store = klass.as_cache[:store] || begin
        if stores.size == 1
          stores.keys.first
        else
          raise Error, "Cannot determine default cache store (store size is not 1: #{@stores.keys.sort.inspect})"
        end
      end
      if @stores.include? store
        send store
      else
        raise Error, "Invalid cache store used (#{store.inspect}, valid: #{@stores.keys.sort.inspect})"
      end
    end

    def self.get(klass, id)
      if cache_json = store(klass).get(klass.cache_key(id))
        klass.load_cache_json JSON.parse(cache_json)
      end
    end

    def self.set(instance)
      store(instance.class).set(instance.class.cache_key(instance.id), instance.to_cache_json)
    end

  private

    def self.stores
      @stores ||= {}
    end

  end
end