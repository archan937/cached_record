require File.expand_path("../../test_helper", __FILE__)

module Unit
  class TestCache < MiniTest::Unit::TestCase

    describe CachedRecord::Cache do
      after do
        CachedRecord::Cache.instance_variable_set :@stores, nil
      end

      describe "memcached" do
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

      describe "redis" do
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
              @klass.expects(:as_cache).returns({})
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
        describe ".get" do
          before do
            @klass = mock
            @klass.expects(:cache_key).returns("mock.123")
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
          describe "without cache entry" do
            it "returns nil" do
              store = mock
              store.expects(:get).with("mock.123").returns(nil)
              CachedRecord::Cache.expects(:store).with(@klass).returns(store)
              assert_equal nil, CachedRecord::Cache.get(@klass, 123)
            end
          end
        end
        describe ".set" do
          it "stores cache JSON" do
            id = 123
            klass = mock
            klass.expects(:cache_key).with(id).returns("mock.123")
            instance = mock
            instance.expects(:id).returns(id)
            instance.expects(:class).at_least_once.returns(klass)
            instance.expects(:to_cache_json).returns('{"id":123}')
            store = mock
            store.expects(:set).with("mock.123", '{"id":123}')
            CachedRecord::Cache.expects(:store).returns(store)
            CachedRecord::Cache.set instance
          end
        end
      end
    end

  end
end