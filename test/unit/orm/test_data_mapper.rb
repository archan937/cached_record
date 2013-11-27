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

      class Earticle
        include DataMapper::Resource
        storage_names[:default] = "articles"
        property :id, Serial, :key => true
        property :title, String
        property :content, Text
        as_cache :redis, :only => [:title, :content], :memoize => {:random_array => :@array}, :include_root => true

        def random_array
          @array ||= [rand(10)]
        end
      end

      class Farticle
        include DataMapper::Resource
        storage_names[:default] = "articles"
        property :id, Serial, :key => true
        property :title, String
        property :content, Text
        as_memoized_cache :redis, :only => [:title, :content], :memoize => {:random_array => :@array}, :include_root => true

        def random_array
          @array ||= [rand(10)]
        end
      end

      class Garticle
        include DataMapper::Resource
        storage_names[:default] = "articles"
        property :id, Serial, :key => true
        property :title, String
        belongs_to :author, :model => "Unit::ORM::TestDataMapper::User"
        has n, :comments, :model => "Unit::ORM::TestDataMapper::Comment", :child_key => "article_id"
        has n, :taggings, :model => "Unit::ORM::TestDataMapper::Tagging", :child_key => "article_id"
        has n, :tags, :through => :taggings
        as_memoized_cache :redis, :only => [:title], :include => [:author, :comments, :tags]
      end

      class User
        include DataMapper::Resource
        storage_names[:default] = "users"
        property :id, Serial, :key => true
        property :name, String
        has 1, :foo, :model => "Unit::ORM::TestDataMapper::Article", :child_key => "foo_id"
        as_memoized_cache :memcached, :only => [:name], :include => [:foo]
      end

      class Comment
        include DataMapper::Resource
        storage_names[:default] = "comments"
        property :id, Serial, :key => true
        property :content, Text
        belongs_to :article, :model => "Unit::ORM::TestDataMapper::Garticle"
        belongs_to :poster, :model => "Unit::ORM::TestDataMapper::User"
        as_memoized_cache :redis, :only => [:content], :include => [:poster]
      end

      class Tag
        include DataMapper::Resource
        storage_names[:default] = "tags"
        property :id, Serial, :key => true
        property :name, String
        has n, :articles, :model => "Unit::ORM::TestDataMapper::Garticle", :through => Resource
        as_memoized_cache :redis, :only => [:name]
      end

      class Tagging
        include DataMapper::Resource
        storage_names[:default] = "articles_tags"
        property :id, Serial, :key => true
        belongs_to :article, :model => "Unit::ORM::TestDataMapper::Garticle"
        belongs_to :tag, :model => "Unit::ORM::TestDataMapper::Tag"
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
            @memcached = Dalli::Client.new
          end

          describe "Article" do
            it "returns its cache JSON hash" do
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries",
                :foo_id => 2
              }, Article.get(1).as_cache_json)
            end
            it "can be stored in the cache store" do
              Article.cached 1
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries",
                :foo_id => 2
              }, @redis.get("unit.orm.test_data_mapper.article.1"))
            end
            it "can be fetched from the cache store" do
              Article.expects(:get).never
              @redis.set(
                "unit.orm.test_data_mapper.article.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database queries"
                }.to_json
              )
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries",
                :foo_id => 2
              }, Article.cached(1).attributes)
            end
            it "is not a new" do
              assert_equal false, Article.cached(1).new?
            end
          end

          describe "Barticle" do
            it "returns its cache JSON hash" do
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries"
              }, Barticle.get(1).as_cache_json)
            end
            it "can be stored in the cache store" do
              Barticle.cached(1)
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries"
              }, @redis.get("unit.orm.test_data_mapper.barticle.1"))
            end
            it "can be fetched from the cache store" do
              Barticle.expects(:get).never
              @redis.set(
                "unit.orm.test_data_mapper.barticle.1", {
                  "id" => 1,
                  "title" => "Behold! It's CachedRecord!",
                  "content" => "Cache ORM instances to avoid database queries"
                }.to_json
              )
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries"
              }, Barticle.cached(1).attributes)
            end
          end

          describe "Carticle" do
            it "returns its cache JSON hash" do
              c = Carticle.get(1)
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
              }, @redis.get("unit.orm.test_data_mapper.carticle.1"))
            end
            it "can be fetched from the cache store" do
              Carticle.expects(:get).never
              @redis.set(
                "unit.orm.test_data_mapper.carticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database queries",
                  :@random_array => [3]
                }.to_json
              )
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries"
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
              d = Darticle.get(1)
              d.expects(:rand).returns(5)
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries",
                :@array => [5]
              }, d.as_cache_json)
            end
            it "can be stored in the cache store" do
              Darticle.any_instance.expects(:rand).returns(4)
              Darticle.cached(1)
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries",
                :@array => [4]
              }.to_json, @redis.get("unit.orm.test_data_mapper.darticle.1"))
            end
            it "can be fetched from the cache store" do
              Darticle.expects(:get).never
              @redis.set(
                "unit.orm.test_data_mapper.darticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database queries",
                  :@array => [3]
                }.to_json
              )
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries"
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
              e = Earticle.get(1)
              e.expects(:rand).returns(5)
              assert_equal_hashes({
                :earticle => {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :content => "Cache ORM instances to avoid database queries"
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
                  :content => "Cache ORM instances to avoid database queries"
                },
                :array => [4]
              }, @redis.get("unit.orm.test_data_mapper.earticle.1"))
            end
            it "can be fetched from the cache store" do
              Earticle.expects(:get).never
              @redis.set(
                "unit.orm.test_data_mapper.earticle.1", {
                  :earticle => {
                    :id => 1,
                    :title => "Behold! It's CachedRecord!",
                    :content => "Cache ORM instances to avoid database queries"
                  },
                  :array => [3]
                }.to_json
              )
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries"
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
              Farticle.expects(:get).never
              @redis.set(
                "unit.orm.test_data_mapper.farticle.1", {
                  :farticle => {
                    :id => 1,
                    :title => "Behold! It's CachedRecord!",
                    :content => "Cache ORM instances to avoid database queries"
                  },
                  :array => [3]
                }.to_json
              )
              assert_equal_hashes({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :content => "Cache ORM instances to avoid database queries"
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
              g = Garticle.get(1)
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
              }, @redis.get("unit.orm.test_data_mapper.garticle.1"))
              assert_equal_hashes({
                :id => 1,
                :name => "Paul Engel",
                :_foo_id => nil
              }, @memcached.get("unit.orm.test_data_mapper.user.1"))
              assert_equal_hashes({
                :id => 2,
                :name => "Ken Adams",
                :_foo_id => 1
              }, @memcached.get("unit.orm.test_data_mapper.user.2"))
              assert_equal_hashes({
                :id => 1,
                :content => "What a great article! :)",
                :poster_id => 2
              }, @redis.get("unit.orm.test_data_mapper.comment.1"))
              assert_equal_hashes({
                :id => 2,
                :content => "Thanks!",
                :poster_id => 1
              }, @redis.get("unit.orm.test_data_mapper.comment.2"))
            end
            it "can be fetched from the cache store" do
              Garticle.expects(:get).never
              User.expects(:get).never
              Comment.expects(:get).never
              Tag.expects(:get).never
              @redis.set(
                "unit.orm.test_data_mapper.garticle.1", {
                  :id => 1,
                  :title => "Behold! It's CachedRecord!",
                  :author_id => 1,
                  :_comment_ids => [1, 2],
                  :_tag_ids => [1, 2]
                }.to_json
              )
              @memcached.set(
                "unit.orm.test_data_mapper.user.1", {
                  :id => 1,
                  :name => "Paul Engel"
                }.to_json
              )
              @memcached.set(
                "unit.orm.test_data_mapper.user.2", {
                  :id => 2,
                  :name => "Ken Adams"
                }.to_json
              )
              @redis.set(
                "unit.orm.test_data_mapper.comment.1", {
                  :id => 1,
                  :content => "What a great article! :)",
                  :poster_id => 2
                }.to_json
              )
              @redis.set(
                "unit.orm.test_data_mapper.comment.2", {
                  :id => 2,
                  :content => "Thanks!",
                  :poster_id => 1
                }.to_json
              )
              @redis.set(
                "unit.orm.test_data_mapper.tag.1", {
                  :id => 1,
                  :name => "ruby"
                }.to_json
              )
              @redis.set(
                "unit.orm.test_data_mapper.tag.2", {
                  :id => 2,
                  :name => "gem"
                }.to_json
              )
              g = Garticle.cached(1)
              assert_equal({
                :id => 1,
                :title => "Behold! It's CachedRecord!",
                :author_id => 1
              }, g.attributes)
              assert_equal({
                :id => 1,
                :name => "Paul Engel"
              }, g.author.attributes)
              assert_equal([{
                :id => 1,
                :name => "ruby"
              }, {
                :id => 2,
                :name => "gem"
              }], g.tags.collect(&:attributes))
              assert_equal([{
                :id => 1,
                :content => "What a great article! :)",
                :article_id => 1,
                :poster_id => 2
              }, {
                :id => 2,
                :content => "Thanks!",
                :article_id => 1,
                :poster_id => 1
              }], g.comments.collect(&:attributes))
              assert_equal([{
                :id => 2,
                :name => "Ken Adams"
              }, {
                :id => 1,
                :name => "Paul Engel"
              }], g.comments.collect{|x| x.poster.attributes})
              assert_equal g.author.object_id, g.comments[1].poster.object_id
            end
          end
        end
      end

    end
  end
end