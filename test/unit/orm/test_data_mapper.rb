require File.expand_path("../../../test_helper", __FILE__)

module Unit
  module ORM
    class TestDataMapper < MiniTest::Unit::TestCase

      class Article
        include DataMapper::Resource
        storage_names[:default] = "articles"
        property :id, Serial, :key => true
        property :title, String
        property :content, Text
        as_cache :redis
      end

      class Barticle
        include DataMapper::Resource
        storage_names[:default] = "articles"
        property :id, Serial, :key => true
        property :title, String
        property :content, Text
        as_cache :redis, :only => [:title, :content]
      end

      class Carticle
        include DataMapper::Resource
        storage_names[:default] = "articles"
        property :id, Serial, :key => true
        property :title, String
        property :content, Text
        as_cache :redis, :only => [], :memoize => [:random_array]

        def random_array
          @random_array ||= [rand(10)]
        end
      end

      class Darticle
        include DataMapper::Resource
        storage_names[:default] = "articles"
        property :id, Serial, :key => true
        property :title, String
        property :content, Text
        as_cache :redis, :only => [:title, :content], :memoize => {:random_array => :@array}

        def random_array
          @array ||= [rand(10)]
        end
      end

      DataMapper.finalize

      describe CachedRecord::ORM::DataMapper do
        describe "when DataMapper is not defined" do
          it "knows not to setup DataMapper::Resource" do
            CachedRecord::ORM::DataMapper.expects(:setup?).returns false
            DataMapper::Resource.expects(:send).with(:include, CachedRecord::ORM::InstanceMethods).never
            DataMapper::Resource.expects(:send).with(:include, CachedRecord::ORM::DataMapper::InstanceMethods).never
            CachedRecord::ORM::DataMapper.setup
          end
        end

        describe "when DataMapper is defined" do
          it "knows to setup DataMapper::Resource" do
            CachedRecord::ORM::DataMapper.expects(:setup?).returns true
            DataMapper::Resource.expects(:send).with(:include, CachedRecord::ORM::InstanceMethods)
            DataMapper::Resource.expects(:send).with(:include, CachedRecord::ORM::DataMapper::InstanceMethods)
            CachedRecord::ORM::DataMapper.setup
          end
        end

        describe "DataMapper::Resource included" do
          before do
            @redis = Redis.new
          end

          describe "Article" do
            it "returns its cache JSON hash" do
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, Article.get(1).as_cache_json)
            end
            it "can be stored in the cache store" do
              Article.cached 1
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }.to_json, @redis.get("unit.orm.test_data_mapper.article.1"))
            end
            it "can be fetched from the cache store" do
              Article.expects(:uncached).never
              @redis.set(
                "unit.orm.test_data_mapper.article.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties"
                }.to_json
              )
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, Article.cached(1).attributes)
            end
          end

          describe "Barticle" do
            it "returns its cache JSON hash" do
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, Barticle.get(1).as_cache_json)
            end
            it "can be stored in the cache store" do
              Barticle.cached(1)
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }.to_json, @redis.get("unit.orm.test_data_mapper.barticle.1"))
            end
            it "can be fetched from the cache store" do
              Barticle.expects(:uncached).never
              @redis.set(
                "unit.orm.test_data_mapper.barticle.1", {
                  "id" => 1,
                  "title" => "Behold! It's CachedRecord!",
                  "content" => "Cache ORM instances to avoid database querties"
                }.to_json
              )
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, Barticle.cached(1).attributes)
            end
          end

          describe "Carticle" do
            it "returns its cache JSON hash" do
              c = Carticle.get(1)
              c.expects(:rand).returns(5)
              assert_equal({
                :id => 1,
                :@random_array => [5]
              }, c.as_cache_json)
            end
            it "can be stored in the cache store" do
              Carticle.any_instance.expects(:rand).returns(4)
              Carticle.cached(1)
              assert_equal({
                :id => 1,
                :@random_array => [4]
              }.to_json, @redis.get("unit.orm.test_data_mapper.carticle.1"))
            end
            it "can be fetched from the cache store" do
              Carticle.expects(:uncached).never
              @redis.set(
                "unit.orm.test_data_mapper.carticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties",
                  :@random_array => [3]
                }.to_json
              )
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, Carticle.cached(1).attributes)
              assert_equal(
                true, Carticle.cached(1).instance_variables.include?(:@random_array)
              )
              assert_equal([
                3
              ], Carticle.cached(1).instance_variable_get(:@random_array))
            end
          end

          describe "Darticle" do
            it "returns its cache JSON hash" do
              c = Darticle.get(1)
              c.expects(:rand).returns(5)
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties",
                :@array => [5]
              }, c.as_cache_json)
            end
            it "can be stored in the cache store" do
              Darticle.any_instance.expects(:rand).returns(4)
              Darticle.cached(1)
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties",
                :@array => [4]
              }.to_json, @redis.get("unit.orm.test_data_mapper.darticle.1"))
            end
            it "can be fetched from the cache store" do
              Darticle.expects(:uncached).never
              @redis.set(
                "unit.orm.test_data_mapper.darticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties",
                  :@array => [3]
                }.to_json
              )
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, Darticle.cached(1).attributes)
              assert_equal(
                true, Darticle.cached(1).instance_variables.include?(:@array)
              )
              assert_equal([
                3
              ], Darticle.cached(1).instance_variable_get(:@array))
            end
          end
        end
      end

    end
  end
end