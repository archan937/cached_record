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

      class Earticle < ActiveRecord::Base
        self.table_name = "articles"
        as_cache :memcached, :only => [:title, :content], :memoize => {:random_array => :@array}, :include_root => true

        def random_array
          @array ||= [rand(10)]
        end
      end

      class Farticle < ActiveRecord::Base
        self.table_name = "articles"
        as_memoized_cache :memcached, :only => [:title, :content], :memoize => {:random_array => :@array}, :include_root => true

        def random_array
          @array ||= [rand(10)]
        end
      end

      class Garticle < ActiveRecord::Base
        self.table_name = "articles"
        belongs_to :author, :class_name => "Unit::ORM::TestActiveRecord::User"
        has_many :comments, :class_name => "Unit::ORM::TestActiveRecord::Comment", :foreign_key => "article_id"
        has_and_belongs_to_many :tags, :class_name => "Unit::ORM::TestActiveRecord::Tag", :join_table => "articles_tags", :foreign_key => "article_id"
        as_memoized_cache :memcached, :only => [:title], :include => [:author, :comments, :tags]
      end

      class User < ActiveRecord::Base
        has_one :foo, :class_name => "Unit::ORM::TestActiveRecord::Article", :foreign_key => "foo_id"
        as_memoized_cache :redis, :only => [:name], :include => [:foo]
      end

      class Comment < ActiveRecord::Base
        belongs_to :article, :class_name => "Unit::ORM::TestActiveRecord::Garticle"
        belongs_to :poster, :class_name => "Unit::ORM::TestActiveRecord::User"
        as_memoized_cache :memcached, :only => [:content], :include => [:poster]
      end

      class Tag < ActiveRecord::Base
        has_and_belongs_to_many :articles, :class_name => "Unit::ORM::TestActiveRecord::Garticle", :join_table => "articles_tags", :foreign_key => "tag_id"
        as_memoized_cache :memcached, :only => [:name]
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
            @redis = Redis.new
          end

          describe "Article" do
            it "returns its cache JSON hash" do
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties",
                :author_id => 1,
                :foo_id => 2,
                :published_at => Time.parse("2013-08-01 12:00:00"),
                :created_at => Time.parse("2013-08-01 10:00:00"),
                :updated_at => Time.parse("2013-08-01 11:00:00")
              }, Article.find(1).as_cache_json)
            end
            it "can be stored in the cache store" do
              Article.cached 1
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties",
                :author_id => 1,
                :foo_id => 2,
                :published_at => Time.parse("2013-08-01 12:00:00"),
                :created_at => Time.parse("2013-08-01 10:00:00"),
                :updated_at => Time.parse("2013-08-01 11:00:00")
              }, @memcached.get("unit.orm.test_active_record.article.1"))
            end
            it "can be fetched from the cache store" do
              Article.expects(:find).never
              @memcached.set(
                "unit.orm.test_active_record.article.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties",
                  :author_id => 1,
                  :foo_id => 2,
                  :published_at => Time.parse("2013-08-01 12:00:00"),
                  :created_at => Time.parse("2013-08-01 10:00:00"),
                  :updated_at => Time.parse("2013-08-01 11:00:00")
                }.to_json
              )
              assert_equal_hashes({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => 1,
                "foo_id" => 2,
                "published_at" => Time.parse("2013-08-01 12:00:00"),
                "created_at" => Time.parse("2013-08-01 10:00:00"),
                "updated_at" => Time.parse("2013-08-01 11:00:00")
              }, Article.cached(1).attributes)
            end
            it "is not a new record" do
              assert_equal false, Article.cached(1).new_record?
            end
          end

          describe "Barticle" do
            it "returns its cache JSON hash" do
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, Barticle.find(1).as_cache_json)
            end
            it "can be stored in the cache store" do
              Barticle.cached(1)
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties"
              }, @memcached.get("unit.orm.test_active_record.barticle.1"))
            end
            it "can be fetched from the cache store" do
              Barticle.expects(:find).never
              @memcached.set(
                "unit.orm.test_active_record.barticle.1", {
                  "id" => 1,
                  "title" => "Behold! It's CachedRecord!",
                  "content" => "Cache ORM instances to avoid database querties"
                }.to_json
              )
              assert_equal_hashes({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => nil,
                "foo_id" => nil,
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
              assert_equal_hashes({
                :id => 1,
                :@random_array => [5]
              }, c.as_cache_json)
            end
            it "can be stored in the cache store" do
              Carticle.any_instance.expects(:rand).returns(4)
              Carticle.cached(1)
              assert_equal_hashes({
                :id => 1,
                :@random_array => [4]
              }, @memcached.get("unit.orm.test_active_record.carticle.1"))
            end
            it "can be fetched from the cache store" do
              Carticle.expects(:find).never
              @memcached.set(
                "unit.orm.test_active_record.carticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties",
                  :@random_array => [3]
                }.to_json
              )
              assert_equal_hashes({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => nil,
                "foo_id" => nil,
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
              d = Darticle.find(1)
              d.expects(:rand).returns(5)
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties",
                :@array => [5]
              }, d.as_cache_json)
            end
            it "can be stored in the cache store" do
              Darticle.any_instance.expects(:rand).returns(4)
              Darticle.cached(1)
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database querties",
                :@array => [4]
              }, @memcached.get("unit.orm.test_active_record.darticle.1"))
            end
            it "can be fetched from the cache store" do
              Darticle.expects(:find).never
              @memcached.set(
                "unit.orm.test_active_record.darticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties",
                  :@array => [3]
                }.to_json
              )
              assert_equal_hashes({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => nil,
                "foo_id" => nil,
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

          describe "Earticle" do
            it "returns its cache JSON hash" do
              e = Earticle.find(1)
              e.expects(:rand).returns(5)
              assert_equal_hashes({
                :earticle => {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties"
                },
                :array => [5]
              }, e.as_cache_json)
            end
            it "can be stored in the cache store" do
              Earticle.any_instance.expects(:rand).returns(4)
              Earticle.cached(1)
              assert_equal_hashes({
                :earticle => {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database querties"
                },
                :array => [4]
              }, @memcached.get("unit.orm.test_active_record.earticle.1"))
            end
            it "can be fetched from the cache store" do
              Earticle.expects(:find).never
              @memcached.set(
                "unit.orm.test_active_record.earticle.1", {
                  :earticle => {
                    :id => 1,
                    :title => "Behold! It's CachedRecord!",
                    :content => "Cache ORM instances to avoid database querties"
                  },
                  :array => [3]
                }.to_json
              )
              assert_equal_hashes({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => nil,
                "foo_id" => nil,
                "published_at" => nil,
                "created_at" => nil,
                "updated_at" => nil
              }, Earticle.cached(1).attributes)
              assert_equal(
                true, Earticle.cached(1).instance_variables.include?(:@array)
              )
              assert_equal([
                3
              ], Earticle.cached(1).instance_variable_get(:@array))
            end
            it "is not memoized" do
              assert_equal false, (Earticle.cached(1).object_id == Earticle.cached(1).object_id)
            end
          end

          describe "Farticle" do
            it "can be fetched from the cache store" do
              Farticle.expects(:find).never
              @memcached.set(
                "unit.orm.test_active_record.farticle.1", {
                  :farticle => {
                    :id => 1,
                    :title => "Behold! It's CachedRecord!",
                    :content => "Cache ORM instances to avoid database querties"
                  },
                  :array => [3]
                }.to_json
              )
              assert_equal_hashes({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => "Cache ORM instances to avoid database querties",
                "author_id" => nil,
                "foo_id" => nil,
                "published_at" => nil,
                "created_at" => nil,
                "updated_at" => nil
              }, Farticle.cached(1).attributes)
              assert_equal(
                true, Farticle.cached(1).instance_variables.include?(:@array)
              )
              assert_equal([
                3
              ], Farticle.cached(1).instance_variable_get(:@array))
            end
            it "is memoized" do
              assert_equal Farticle.cached(1).object_id, Farticle.cached(1).object_id
              assert_equal Farticle.cached(1).object_id, Farticle.cached(1).object_id
            end
          end

          describe "Garticle" do
            it "returns its cache JSON hash" do
              g = Garticle.find(1)
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :author_id => 1,
                :_comment_ids => [1, 2],
                :_tag_ids => [1, 2]
              }, g.as_cache_json)
            end
            it "can be stored in the cache store" do
              Garticle.cached(1)
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :author_id => 1,
                :_comment_ids => [1, 2],
                :_tag_ids => [1, 2]
              }, @memcached.get("unit.orm.test_active_record.garticle.1"))
              assert_equal_hashes({
                :id => 1,
                :name => "Paul Engel",
                :_foo_id => nil
              }, @redis.get("unit.orm.test_active_record.user.1"))
              assert_equal_hashes({
                :id => 2,
                :name => "Ken Adams",
                :_foo_id => 1
              }, @redis.get("unit.orm.test_active_record.user.2"))
              assert_equal_hashes({
                :id => 1,
                :content => "What a great article! :)",
                :poster_id => 2
              }, @memcached.get("unit.orm.test_active_record.comment.1"))
              assert_equal_hashes({
                :id => 2,
                :content => "Thanks!",
                :poster_id => 1
              }, @memcached.get("unit.orm.test_active_record.comment.2"))
            end
            it "can be fetched from the cache store" do
              Garticle.expects(:find).never
              User.expects(:find).never
              Comment.expects(:find).never
              Tag.expects(:find).never
              @memcached.set(
                "unit.orm.test_active_record.garticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :author_id => 1,
                  :_comment_ids => [1, 2],
                  :_tag_ids => [1, 2]
                }.to_json
              )
              @redis.set(
                "unit.orm.test_active_record.user.1", {
                  :id => 1,
                  :name => "Paul Engel"
                }.to_json
              )
              @redis.set(
                "unit.orm.test_active_record.user.2", {
                  :id => 2,
                  :name => "Ken Adams"
                }.to_json
              )
              @memcached.set(
                "unit.orm.test_active_record.comment.1", {
                  :id => 1,
                  :content => "What a great article! :)",
                  :poster_id => 2
                }.to_json
              )
              @memcached.set(
                "unit.orm.test_active_record.comment.2", {
                  :id => 2,
                  :content => "Thanks!",
                  :poster_id => 1
                }.to_json
              )
              @memcached.set(
                "unit.orm.test_active_record.tag.1", {
                  :id => 1,
                  :name => "ruby"
                }.to_json
              )
              @memcached.set(
                "unit.orm.test_active_record.tag.2", {
                  :id => 2,
                  :name => "gem"
                }.to_json
              )
              g = Garticle.cached(1)
              assert_equal({
                "id" => 1,
                "title" => "Behold! It's CachedRecord!",
                "content" => nil,
                "author_id" => 1,
                "foo_id" => nil,
                "published_at" => nil,
                "created_at" => nil,
                "updated_at" => nil
              }, g.attributes)
              assert_equal({
                "id" => 1,
                "name" => "Paul Engel",
                "description" => nil,
                "active" => nil,
                "created_at" => nil,
                "updated_at" => nil
              }, g.author.attributes)
              assert_equal([{
                "id" => 1,
                "name" => "ruby",
                "created_at" => nil,
                "updated_at" => nil
              }, {
                "id" => 2,
                "name" => "gem",
                "created_at" => nil,
                "updated_at" => nil
              }], g.tags.collect(&:attributes))
              assert_equal([{
                "id" => 1,
                "content" => "What a great article! :)",
                "article_id" => nil,
                "poster_id" => 2,
                "created_at" => nil,
                "updated_at" => nil
              }, {
                "id" => 2,
                "content" => "Thanks!",
                "article_id" => nil,
                "poster_id" => 1,
                "created_at" => nil,
                "updated_at" => nil
              }], g.comments.collect(&:attributes))
              assert_equal([{
                "id" => 2,
                "name" => "Ken Adams",
                "description" => nil,
                "active" => nil,
                "created_at" => nil,
                "updated_at" => nil
              }, {
                "id" => 1,
                "name" => "Paul Engel",
                "description" => nil,
                "active" => nil,
                "created_at" => nil,
                "updated_at" => nil
              }], g.comments.collect{|x| x.poster.attributes})
              assert_equal g.author.object_id, g.comments[1].poster.object_id
            end
          end
        end
      end

    end
  end
end