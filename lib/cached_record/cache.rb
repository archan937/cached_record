require "dalli"
require "redis"

module CachedRecord
  module Cache
    class Error < StandardError; end

    def self.setup(store, options = {})
      if valid_store? store
        send store, options
      end
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

    def self.cache
      @cache ||= {Dalli::Client => {}, Redis => {}}
    end

    def self.clear!
      @cache = nil
    end

    def self.get(klass, id)
      cache_string = store(klass).get(klass.cache_key(id)) || begin
        return unless (instance = yield if block_given?)
        set instance
      end
      json, epoch_time = split_cache_string(cache_string)
      memoized(klass, id, epoch_time) do
        klass.load_cache_json JSON.parse(json)
      end
    end

    def self.set(instance)
      "#{instance.to_cache_json}#{"@#{Time.now.to_i}" if instance.class.as_cache[:memoize]}".tap do |cache_string|
        store(instance.class).set instance.class.cache_key(instance.id), cache_string, instance.class.as_cache[:expire]
      end
    end

    def self.expire(instance)
      klass = instance.class
      cache_key = klass.cache_key instance.id
      store(klass).delete cache_key
      cache[store(klass).class].delete cache_key if klass.as_cache[:memoize]
      nil
    end

    def self.memoized(klass, id, epoch_time)
      return yield unless klass.as_cache[:memoize]
      cache_hash, cache_key = cache[store(klass).class], klass.cache_key(id)

      if (cache_entry = cache_hash[cache_key]) && (epoch_time == cache_entry[:epoch_time])
        cache_entry[:instance]
      else
        yield.tap do |instance|
          cache_hash[cache_key] = {:instance => instance, :epoch_time => epoch_time} if instance
        end
      end
    end

  private

    def self.valid_store?(arg)
      [:memcached, :redis].include?(arg.to_sym)
    end

    def self.stores
      @stores ||= {}
    end

    def self.store(klass)
      store = klass.as_cache[:store] || begin
        if stores.size == 1
          stores.keys.first
        else
          raise Error, "Cannot determine default cache store (store size is not 1: #{@stores.keys.sort.inspect})"
        end
      end
      if valid_store?(store)
        send(store)
      else
        raise Error, "Invalid cache store :#{store} passed"
      end
    end

    def self.split_cache_string(string)
      reg_exp = /@(\d+)$/
      string.match(reg_exp)
      json = string.gsub(reg_exp, "")
      epoch_time = $1.to_i if $1
      [json, epoch_time]
    end

  end
end