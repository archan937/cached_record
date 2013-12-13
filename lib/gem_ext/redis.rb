begin
  require "redis"
rescue LoadError
end

class Redis

  alias :set_without_cached_record :set
  def set(key, value, ttl_or_options = nil)
    if ttl_or_options.is_a? Integer
      ttl = ttl_or_options
      options = {}
    else
      options = ttl_or_options || {}
    end
    set_without_cached_record(key, value, options).tap do
      expire key, ttl if ttl
    end
  end

  def delete(*args)
    del *args
  end

end