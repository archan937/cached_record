require File.expand_path("../../test_helper", __FILE__)

module Unit
  class TestORM < MiniTest::Unit::TestCase

    class A
      include CachedRecord::ORM
      as_cache :redis, "only" => [:title], :include => ["@memval"]
    end

    describe CachedRecord::ORM do
      describe "when extended within a class" do

        describe "classes" do
          it "validates and parses 'as cache json options'" do
            assert_raises ArgumentError do
              A.as_cache :foonly => []
            end
            assert_raises ArgumentError do
              A.as_cache :only => :foo
            end
          end
          it "stores its cache options" do
            assert_equal({:store => :redis, :as_json => {:only => [:title], :include => [:@memval]}}, A.as_cache)
          end
          it "memoizes its cache options" do
            options = A.as_cache
            assert_equal options.object_id, A.as_cache.object_id
          end
          it "returns cache keys" do
            assert_equal "unit.test_orm.a.123", A.cache_key(123)
          end
          it "requires an implemented `uncached` method" do
            assert_raises NotImplementedError do
              A.uncached 1
            end
          end
          it "requires an implemented `load_cache_json` method" do
            assert_raises NotImplementedError do
              A.load_cache_json "{}"
            end
          end
        end

        describe "instances" do
          it "requires an implemented `as_cache_json` method" do
            assert_raises NotImplementedError do
              A.new.as_cache_json
            end
          end
          it "knows its as cache JSON options" do
            assert_equal({:only => [:title], :include => [:@memval]}, A.new.send(:cache_json_options))
          end
          it "returns a cache JSON string" do
            hash = mock
            hash.expects(:to_json)
            a = A.new
            a.expects(:as_cache_json).returns(hash)
            a.to_cache_json
          end
        end

        describe ".cached" do
          describe "when not having a cache entry" do
            it "returns an uncached instance and stores its cache JSON in the cache store" do
              uncached_instance = mock
              CachedRecord::Cache.expects(:get).with(A, 123).returns nil
              A.expects(:uncached).with(123).returns uncached_instance
              CachedRecord::Cache.expects(:set).with uncached_instance
              assert_equal uncached_instance, A.cached(123)
            end
          end
          describe "when having a cache entry" do
            it "returns a cached instance" do
              cached_instance = mock
              CachedRecord::Cache.expects(:get).with(A, 123).returns cached_instance
              assert_equal cached_instance, A.cached(123)
            end
          end
        end

      end
    end

  end
end