class MiniTest::Unit::TestCase
  def teardown
    Redis.new.flushdb
    Dalli::Client.new.flush
    CachedRecord::Cache.clear!
  end
end

module MiniTest::Assertions
  def assert_equal_hashes exp, act, msg = nil
    msg = message(msg, "") { diff exp, act }
    exp = JSON.parse(exp) if exp.is_a?(String)
    act = JSON.parse(act) if act.is_a?(String)
    assert(recursive_symbolize_keys(exp) == recursive_symbolize_keys(act), msg)
  end
private
  def recursive_symbolize_keys(hash)
    hash.inject({}) do |hash, (key, value)|
      hash[key.to_sym] = value.is_a?(Hash) ? recursive_symbolize_keys(hash) : value
      hash
    end
  end
end