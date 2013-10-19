require File.expand_path("../../../test_helper", __FILE__)

module Unit
  module ORM
    class TestDataMapper < MiniTest::Unit::TestCase

      module A
        class Article
          include DataMapper::Resource
          storage_names[:default] = "articles"
          property :id, Serial, :key => true
          property :title, String
          property :content, Text
        end
      end

      describe CachedRecord::ORM::DataMapper do
        it "knows not to setup DataMapper::Resource" do
          CachedRecord::ORM::DataMapper.expects(:setup?).returns false
          DataMapper::Resource.expects(:send).with(:include, CachedRecord::ORM::InstanceMethods).never
          DataMapper::Resource.expects(:send).with(:include, CachedRecord::ORM::DataMapper::InstanceMethods).never
          CachedRecord::ORM::DataMapper.setup
        end

        it "knows to setup DataMapper::Resource" do
          CachedRecord::ORM::DataMapper.expects(:setup?).returns true
          DataMapper::Resource.expects(:send).with(:include, CachedRecord::ORM::InstanceMethods)
          DataMapper::Resource.expects(:send).with(:include, CachedRecord::ORM::DataMapper::InstanceMethods)
          CachedRecord::ORM::DataMapper.setup
        end

        describe "DataMapper::Resource included" do
          it "returns its cache JSON hash" do
            assert_equal({
              :id => 1,
              :title => "Behold! It's CachedRecord!",
              :content => "Cache ORM instances to avoid database querties"
            }, A::Article.get(1).as_cache_json)
          end
        end
      end

    end
  end
end