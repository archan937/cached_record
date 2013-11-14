require File.expand_path("../../../test_helper", __FILE__)

module Unit
  module ORM
    class TestActiveRecord < MiniTest::Unit::TestCase

      class Article < ActiveRecord::Base
        as_cache :memcached
      end

      class Barticle < ActiveRecord::Base
        self.table_name = "articles"
        as_cache :memcached, :only => [:title, :content]
      end

      class Carticle < ActiveRecord::Base
        self.table_name = "articles"
        as_cache :memcached, :only => [], :memoize => [:random_array]

        def random_array
          @random_array ||= [rand(10)]
        end
      end

      class Darticle < ActiveRecord::Base
        self.table_name = "articles"
        as_cache :memcached, :only => [:title, :content], :memoize => {:random_array => :@array}

        def random_array
          @array ||= [rand(10)]
        end
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
            @memcached = Dalli::Client.new
          end

          describe "Article" do
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
              Article.cached(1)
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

          describe "Barticle" do
            it "returns its cache JSON hash" do
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, Barticle.find(1).as_cache_json)
            end
            it "can be stored in the cache store" do
              Barticle.cached(1)
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }.to_json, @memcached.get("unit.orm.test_active_record.barticle.1"))
            end
            it "can be fetched from the cache store" do
              Barticle.expects(:uncached).never
              @memcached.set(
                "unit.orm.test_active_record.barticle.1", {
                  "id" => 1,
                  "title" => "Behold! It's CachedRecord!",
                  "content" => "Cache ORM instances to avoid database querties"
                }.to_json
              )
              assert_equal({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => nil,
                "published_at" => nil,
                "created_at" => nil,
                "updated_at" => nil
              }, Barticle.cached(1).attributes)
            end
          end

          describe "Carticle" do
            it "returns its cache JSON hash" do
              c = Carticle.find(1)
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
              }.to_json, @memcached.get("unit.orm.test_active_record.carticle.1"))
            end
            it "can be fetched from the cache store" do
              Carticle.expects(:uncached).never
              @memcached.set(
                "unit.orm.test_active_record.carticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties",
                  :@random_array => [3]
                }.to_json
              )
              assert_equal({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => nil,
                "published_at" => nil,
                "created_at" => nil,
                "updated_at" => nil
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
              c = Darticle.find(1)
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
              }.to_json, @memcached.get("unit.orm.test_active_record.darticle.1"))
            end
            it "can be fetched from the cache store" do
              Darticle.expects(:uncached).never
              @memcached.set(
                "unit.orm.test_active_record.darticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties",
                  :@array => [3]
                }.to_json
              )
              assert_equal({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => nil,
                "published_at" => nil,
                "created_at" => nil,
                "updated_at" => nil
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