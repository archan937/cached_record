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
      end

    end
  end
end