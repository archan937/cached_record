require File.expand_path("../../test_helper", __FILE__)

module Unit
  class TestORM < MiniTest::Test

    class A
      include CachedRecord::ORM
      as_cache :redis, "only" => [:title], :include => [:b], :memoize => [:sequence]
      def id; end
    end

    class B
      include CachedRecord::ORM
      as_cache :redis, "only" => [:title], :include => [:b], "memoize" => {"calculate" => :@array}
    end

    class C
      include CachedRecord::ORM
      as_cache :redis, :only => [:title], "include" => [:b], :memoize => [:sequence, {:calculate => "@array"}]
    end

    class D
      include CachedRecord::ORM
      as_cache :redis, :only => [:title], :include_root => true
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
            assert_raises ArgumentError do
              A.as_cache :include => :foo
            end
            assert_raises ArgumentError do
              A.as_cache :memoize => :foo
            end
            assert_raises ArgumentError do
              A.as_cache :include_root => :foo
            end
          end
          it "stores its cache options" do
            assert_equal({
              :store => :redis,
              :as_json => {
                :only => [:title],
                :include => [:b],
                :memoize => {:sequence => :@sequence}
              }
            }, A.as_cache)
            assert_equal({
              :store => :redis,
              :as_json => {
                :only => [:title],
                :include => [:b],
                :memoize => {:calculate => :@array}
              }
            }, B.as_cache)
            assert_equal({
              :store => :redis,
              :as_json => {
                :only => [:title],
                :include => [:b],
                :memoize => {:sequence => :@sequence, :calculate => :@array}
              }
            }, C.as_cache)
            assert_equal({
              :store => :redis,
              :as_json => {
                :only => [:title],
                :include_root => true
              }
            }, D.as_cache)
          end
          it "stores whether it should memoize instances" do
            options = {}
            A.expects(:as_cache).with(:foo => :bar).returns(options)
            A.as_memoized_cache :foo => :bar
            assert_equal options, {:memoize => true}
          end
          it "memoizes its cache options" do
            options = A.as_cache
            assert_equal options.object_id, A.as_cache.object_id
          end
          it "returns cache keys" do
            assert_equal "unit.test_orm.a.123", A.cache_key(123)
          end
          it "returns the cache root" do
            assert_equal :a, A.cache_root
          end
          it "requires an implemented `uncached` method" do
            assert_raises NotImplementedError do
              A.uncached 1
            end
          end
          it "requires an implemented `set_cached_association` method" do
            assert_raises NotImplementedError do
              A.send :set_cached_association, :a, :b, :c
            end
          end
        end

        describe "instances" do
          it "requires an implemented `cache_attributes` method" do
            assert_raises NotImplementedError do
              A.new.cache_attributes
            end
          end
          it "requires an implemented `cache_foreign_keys` method" do
            assert_raises NotImplementedError do
              A.new.cache_foreign_keys
            end
          end
          it "knows its as cache JSON options" do
            assert_equal({
              :only => [:title],
              :include => [:b],
              :memoize => {:sequence => :@sequence}
            }, A.new.send(:cache_json_options))
            assert_equal({
              :only => [:title],
              :include => [:b],
              :memoize => {:calculate => :@array}
            }, B.new.send(:cache_json_options))
            assert_equal({
              :only => [:title],
              :include => [:b],
              :memoize => {:sequence => :@sequence, :calculate => :@array}
            }, C.new.send(:cache_json_options))
            assert_equal({
              :only => [:title],
              :include_root => true
            }, D.new.send(:cache_json_options))
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
              uncached_instance = A.new
              uncached_instance.expects(:to_cache_json).returns({})

              A.stubs(:as_cache).returns({:store => :redis, :as_json => {}})
              A.expects(:uncached).with(123).returns uncached_instance
              A.expects(:new).returns uncached_instance

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

        describe "#cache" do
          it "delegates to class.cached" do
            id, instance = 2, A.new
            instance.expects(:id).returns(id)
            A.expects(:cached).with(id)
            assert instance.cache
          end
        end

        describe "#expire" do
          it "delegates to CachedRecord::Cache.expire" do
            instance = A.new
            CachedRecord::Cache.expects(:expire).with(instance)
            assert instance.expire
          end
        end

      end
    end

  end
end