require File.expand_path("../../test_helper", __FILE__)

module Unit
  class TestCache < MiniTest::Unit::TestCase

    describe CachedRecord::Cache do
      after do
        CachedRecord::Cache.instance_variable_set :@stores, nil
      end

      describe ".memcached" do
        after do
          Dalli::Client.unstub :new
        end
        it "initiates a Dalli::Client instance" do
          Dalli::Client.expects(:new).with "127.0.0.1:11211", {}
          CachedRecord::Cache.memcached :host => "127.0.0.1"
        end
        it "memoizes a Dalli::Client instance" do
          client = mock
          Dalli::Client.expects(:new).returns client
          CachedRecord::Cache.memcached
          assert_equal CachedRecord::Cache.memcached.object_id, client.object_id
          assert_equal CachedRecord::Cache.memcached.object_id, client.object_id
        end
      end

      describe ".redis" do
        after do
          Redis.unstub :new
        end
        it "initiates a Redis instance" do
          Redis.expects(:new).with :host => "127.0.0.1"
          CachedRecord::Cache.redis :host => "127.0.0.1"
        end
        it "memoizes a Redis instance" do
          client = mock
          Redis.expects(:new).returns client
          CachedRecord::Cache.redis
          assert_equal CachedRecord::Cache.redis.object_id, client.object_id
          assert_equal CachedRecord::Cache.redis.object_id, client.object_id
        end
      end

      describe "cache store" do
        describe ".valid_store?" do
          it "returns whether the passed argument is a valid cache store" do
            assert_equal true, CachedRecord::Cache.valid_store?("redis")
            assert_equal true, CachedRecord::Cache.valid_store?("memcached")
            assert_equal true, CachedRecord::Cache.valid_store?(:redis)
            assert_equal true, CachedRecord::Cache.valid_store?(:memcached)
            assert_equal false, CachedRecord::Cache.valid_store?("foo")
            assert_equal false, CachedRecord::Cache.valid_store?(:foo)
          end
        end
        describe ".store" do
          describe "with as_cache[:store]" do
            describe "when valid" do
              it "returns the specified cache client" do
                klass = mock
                klass.expects(:as_cache).returns({:store => :redis})
                CachedRecord::Cache.expects(:send).with(:redis)
                CachedRecord::Cache.store(klass)
              end
            end
            describe "when invalid" do
              it "returns the specified cache client" do
                klass = mock
                klass.expects(:as_cache).returns({:store => :foo})
                assert_raises CachedRecord::Cache::Error do
                  CachedRecord::Cache.store(klass)
                end
              end
            end
          end
          describe "without as_cache[:store]" do
            before do
              @klass = mock
              @klass.stubs(:as_cache).returns({})
            end
            describe "with zero cache stores" do
              it "raises an error" do
                CachedRecord::Cache.instance_variable_set :@stores, {}
                assert_raises CachedRecord::Cache::Error do
                  CachedRecord::Cache.store(@klass)
                end
              end
            end
            describe "with one cache store" do
              it "returns the cache store" do
                CachedRecord::Cache.instance_variable_set :@stores, {:memcached => mock}
                CachedRecord::Cache.store(@klass)
              end
            end
            describe "with multiple cache store" do
              it "raises an error" do
                CachedRecord::Cache.instance_variable_set :@stores, {:memcached => mock, :redis => mock}
                assert_raises CachedRecord::Cache::Error do
                  CachedRecord::Cache.store(@klass)
                end
              end
            end
          end
        end
        describe ".cache" do
          it "returns a Hash" do
            assert_equal({Dalli::Client => {}, Redis => {}}, CachedRecord::Cache.cache)
          end
        end
        describe ".clear!" do
          it "returns a Hash" do
            CachedRecord::Cache.instance_variable_set :@cache, {:foo => :bar}
            assert_equal({:foo => :bar}, CachedRecord::Cache.cache)

            CachedRecord::Cache.clear!
            assert_nil CachedRecord::Cache.instance_variable_get(:@cache)

            assert_equal({Dalli::Client => {}, Redis => {}}, CachedRecord::Cache.cache)
          end
        end
        describe ".get" do
          before do
            @klass = mock
            @klass.stubs(:cache_key).returns("mock.123")
          end
          describe "without memoization" do
            before do
              @klass.stubs(:as_cache).returns({})
            end
            describe "with cache entry" do
              it "returns a cached instance" do
                store = mock
                store.expects(:get).with("mock.123").returns('{"id":123}')
                CachedRecord::Cache.expects(:store).with(@klass).returns(store)

                cached_instance = mock
                @klass.expects(:load_cache_json).with({"id" => 123}).returns cached_instance

                assert_equal cached_instance, CachedRecord::Cache.get(@klass, 123)
              end
            end
          end
          describe "with memoization" do
            before do
              @klass.stubs(:as_cache).returns({:store => :redis, :memoize => true})
            end
            describe "without cache entry" do
              it "returns nil" do
                store = mock
                store.expects(:get).with("mock.123").returns(nil)
                CachedRecord::Cache.expects(:store).with(@klass).returns(store)
                assert_equal nil, CachedRecord::Cache.get(@klass, 123)
              end
            end
            describe "with cache entry" do
              before do
                @store = mock
                @store.stubs(:get).with("mock.123").returns('{"id":123,"foo":"b@r"}@123456')
                @store.stubs(:class).returns(Redis)
                CachedRecord::Cache.stubs(:store).with(@klass).returns(@store)
              end
              describe "without memoized instance" do
                it "returns a memoized instance" do
                  hash = mock
                  instance = mock

                  CachedRecord::Cache.expects(:cache).returns(Redis => hash)
                  hash.expects(:[]).with("mock.123").returns(nil)
                  hash.expects(:[]=).with("mock.123", :instance => instance, :epoch_time => 123456)
                  @klass.expects(:load_cache_json).with({"id" => 123,"foo" => "b@r"}).returns instance

                  assert_equal instance, CachedRecord::Cache.get(@klass, 123)

                  cache = {Redis => {"mock.123" => {:instance => instance, :epoch_time => 123456}}}
                  CachedRecord::Cache.expects(:cache).returns(cache)
                  @klass.expects(:load_cache_json).never

                  assert_equal instance, CachedRecord::Cache.get(@klass, 123)
                end
              end
              describe "with memoized instance" do
                describe "outdated instance" do
                  it "returns a new memoized instance" do
                    hash = mock
                    outdated_instance = mock
                    instance = mock

                    CachedRecord::Cache.expects(:cache).returns(Redis => hash)
                    hash.expects(:[]).with("mock.123").returns({:instance => outdated_instance, :epoch_time => 12345})
                    hash.expects(:[]=).with("mock.123", :instance => instance, :epoch_time => 123456)
                    @klass.expects(:load_cache_json).with({"id" => 123,"foo" => "b@r"}).returns instance

                    assert_equal instance, CachedRecord::Cache.get(@klass, 123)

                    cache = {Redis => {"mock.123" => {:instance => instance, :epoch_time => 123456}}}
                    CachedRecord::Cache.expects(:cache).returns(cache)
                    @klass.expects(:load_cache_json).never

                    assert_equal instance, CachedRecord::Cache.get(@klass, 123)
                  end
                end
                describe "uptodate instance" do
                  it "returns the memoized instance" do
                    hash = mock
                    instance = mock

                    CachedRecord::Cache.expects(:cache).returns(Redis => hash)
                    hash.expects(:[]).with("mock.123").returns({:instance => instance, :epoch_time => 123456})
                    @klass.expects(:load_cache_json).never

                    assert_equal instance, CachedRecord::Cache.get(@klass, 123)
                  end
                end
              end
            end
          end
        end
        describe ".set" do
          before do
            id = 123
            @klass = mock
            @klass.stubs(:cache_key).with(id).returns("mock.123")

            @instance = mock
            @instance.stubs(:id).returns(id)
            @instance.stubs(:class).returns(@klass)
            @instance.stubs(:to_cache_json).returns('{"id":123}')

            @store = mock
            CachedRecord::Cache.stubs(:store).returns(@store)
          end
          describe "without memoization" do
            before do
              @klass.stubs(:as_cache).returns({})
            end
            it "stores cache JSON" do
              @store.expects(:set).with("mock.123", '{"id":123}')
              CachedRecord::Cache.set @instance
            end
          end
          describe "with memoization" do
            before do
              @klass.stubs(:as_cache).returns({:memoize => true})
            end
            it "stores cache JSON" do
              Time.any_instance.expects(:to_i).returns(123456789)
              @store.expects(:set).with("mock.123", '{"id":123}@123456789')
              CachedRecord::Cache.set @instance
            end
          end
        end
        describe ".memoized" do
          describe "not configured for memoization" do
            it "returns nil" do
              klass = mock
              klass.expects(:as_cache).returns({})
              instance = mock

              CachedRecord::Cache.expects(:cache).never
              assert_equal instance, CachedRecord::Cache.memoized(klass, 123, 123456789) { instance }
            end
          end
          describe "configured for memoization" do
            before do
              @klass = mock
              @klass.stubs(:as_cache).returns({:store => :redis, :memoize => true})
              @klass.stubs(:cache_key).returns("mock.123")
            end
            describe "empty cache hash" do
              it "returns nil" do
                hash = mock
                hash.expects(:[]).with("mock.123")
                CachedRecord::Cache.expects(:cache).returns Redis => hash
                assert_nil CachedRecord::Cache.memoized(@klass, 123, 123456789) {}
              end
            end
            describe "matching cache hash entry" do
              before do
                @instance = mock
              end
              describe "non matching epoch time" do
                it "returns nil" do
                  hash = mock
                  hash.expects(:[]).with("mock.123").returns :instance => mock, :epoch_time => 123456789
                  hash.expects(:[]=).with("mock.123", {:instance => @instance, :epoch_time => 987654321})

                  CachedRecord::Cache.expects(:cache).returns Redis => hash
                  assert_equal @instance, CachedRecord::Cache.memoized(@klass, 123, 987654321) { @instance }
                end
              end
              describe "matching epoch time" do
                it "returns memoized instance" do
                  hash = mock
                  hash.expects(:[]).with("mock.123").returns :instance => @instance, :epoch_time => 123456789

                  CachedRecord::Cache.expects(:cache).returns Redis => hash
                  assert_equal @instance, CachedRecord::Cache.memoized(@klass, 123, 123456789) { mock }
                end
              end
            end
          end
        end
        describe ".split_cache_string" do
          it "returns an array containing a JSON string and an optional epoch time integer" do
            assert_equal ["", nil], CachedRecord::Cache.send(:split_cache_string, "")
            assert_equal ['{"id":123,"foo":"b@r"}', nil], CachedRecord::Cache.send(:split_cache_string, '{"id":123,"foo":"b@r"}')
            assert_equal ['{"id":123,"foo":"b@r"}', 123456789], CachedRecord::Cache.send(:split_cache_string, '{"id":123,"foo":"b@r"}@123456789')
          end
        end
      end
    end

  end
end