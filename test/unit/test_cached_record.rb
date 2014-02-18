require File.expand_path("../../test_helper", __FILE__)

module Unit
  class TestCachedRecord < MiniTest::Test

    describe CachedRecord do
      it "has the current version" do
        version = "0.1.0"
        assert_equal version, CachedRecord::VERSION
        assert File.read(path "CHANGELOG.rdoc").include?("Version #{version}")
        assert File.read(path "VERSION").include?(version)
      end

      describe ".setup" do
        it "sets up ActiveRecord, DataMapper and Cache" do
          CachedRecord::Cache.expects(:redis).with(:host => "127.0.0.1")
          CachedRecord::Cache.expects(:memcached).with(:host => "0.0.0.0")
          CachedRecord::ORM::ActiveRecord.expects(:setup)
          CachedRecord::ORM::DataMapper.expects(:setup)
          CachedRecord.setup :redis => {:host => "127.0.0.1"}, :memcached => {:host => "0.0.0.0"}
        end

        it "accepts an array of cache stores" do
          CachedRecord::Cache.expects(:redis)
          CachedRecord::Cache.expects(:memcached)
          CachedRecord::ORM::ActiveRecord.expects(:setup)
          CachedRecord::ORM::DataMapper.expects(:setup)
          CachedRecord.setup :redis, :memcached
        end
      end
    end

  end
end