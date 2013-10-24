require File.expand_path("../../../test_helper", __FILE__)

module Unit
  module ORM
    class TestActiveRecord < MiniTest::Unit::TestCase

      class Article < ActiveRecord::Base
        as_cache :memcached
      end

      describe CachedRecord::ORM::ActiveRecord do
        describe "when ActiveRecord is not defined" do
          it "knows not to setup ActiveRecord::Base" do
            CachedRecord::ORM::ActiveRecord.expects(:setup?).returns false
            ActiveRecord::Base.expects(:extend).with(CachedRecord::ORM::ActiveRecord::ClassMethods).never
            ActiveRecord::Base.expects(:send).with(:include, CachedRecord::ORM).never
            ActiveRecord::Base.expects(:send).with(:include, CachedRecord::ORM::ActiveRecord::InstanceMethods).never
            CachedRecord::ORM::ActiveRecord.setup
          end
        end

        describe "when ActiveRecord is defined" do
          it "knows to setup ActiveRecord::Base" do
            CachedRecord::ORM::ActiveRecord.expects(:setup?).returns true
            ActiveRecord::Base.expects(:extend).with(CachedRecord::ORM::ActiveRecord::ClassMethods)
            ActiveRecord::Base.expects(:send).with(:include, CachedRecord::ORM)
            ActiveRecord::Base.expects(:send).with(:include, CachedRecord::ORM::ActiveRecord::InstanceMethods)
            CachedRecord::ORM::ActiveRecord.setup
          end
        end

        describe "ActiveRecord::Base instances" do
          before do
            @memcached = Dalli::Client.new "localhost:11211"
            @memcached.flush
          end
          it "returns its cache JSON hash" do
            assert_equal({
              :id => 1,
              :title => "Behold! It's CachedRecord!",
              :content => "Cache ORM instances to avoid database querties",
              :author_id => 1,
              :published_at => Time.parse("2013-08-01 12:00:00"),
              :created_at => Time.parse("2013-08-01 10:00:00"),
              :updated_at => Time.parse("2013-08-01 11:00:00")
            }, Article.find(1).as_cache_json)
          end
          it "can be stored in the cache store" do
            Article.cached 1
            assert_equal({
              :id => 1,
              :title => "Behold! It's CachedRecord!",
              :content => "Cache ORM instances to avoid database querties",
              :author_id => 1,
              :published_at => Time.parse("2013-08-01 12:00:00"),
              :created_at => Time.parse("2013-08-01 10:00:00"),
              :updated_at => Time.parse("2013-08-01 11:00:00")
            }.to_json, @memcached.get("unit.orm.test_active_record.article.1"))
          end
          it "can be fetched from the cache store" do
            Article.expects(:uncached).never
            @memcached.set(
              "unit.orm.test_active_record.article.1", {
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties",
                :author_id => 1,
                :published_at => Time.parse("2013-08-01 12:00:00"),
                :created_at => Time.parse("2013-08-01 10:00:00"),
                :updated_at => Time.parse("2013-08-01 11:00:00")
              }.to_json
            )
            assert_equal({
              "id" => 1,
              "title" => "Behold! It's CachedRecord!",
              "content" => "Cache ORM instances to avoid database querties",
              "author_id" => 1,
              "published_at" => Time.parse("2013-08-01 12:00:00"),
              "created_at" => Time.parse("2013-08-01 10:00:00"),
              "updated_at" => Time.parse("2013-08-01 11:00:00")
            }, Article.cached(1).attributes)
          end
        end
      end

    end
  end
end