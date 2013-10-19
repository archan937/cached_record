require File.expand_path("../../../test_helper", __FILE__)

module Unit
  module ORM
    class TestActiveRecord < MiniTest::Unit::TestCase

      module A
        class Article < ActiveRecord::Base
        end
      end

      describe CachedRecord::ORM::ActiveRecord do
        it "knows not to setup ActiveRecord::Base" do
          CachedRecord::ORM::ActiveRecord.expects(:setup?).returns false
          ActiveRecord::Base.expects(:send).with(:include, CachedRecord::ORM).never
          ActiveRecord::Base.expects(:send).with(:include, CachedRecord::ORM::ActiveRecord::InstanceMethods).never
          CachedRecord::ORM::ActiveRecord.setup
        end

        it "knows to setup ActiveRecord::Base" do
          CachedRecord::ORM::ActiveRecord.expects(:setup?).returns true
          ActiveRecord::Base.expects(:send).with(:include, CachedRecord::ORM)
          ActiveRecord::Base.expects(:send).with(:include, CachedRecord::ORM::ActiveRecord::InstanceMethods)
          CachedRecord::ORM::ActiveRecord.setup
        end

        describe "ActiveRecord::Base descendants" do
          it "returns its cache JSON hash" do
            assert_equal({
              :id => 1,
              :title => "Behold! It's CachedRecord!",
              :content => "Cache ORM instances to avoid database querties",
              :author_id => 1,
              :published_at => Time.parse("2013-08-01 12:00:00"),
              :created_at => Time.parse("2013-08-01 10:00:00"),
              :updated_at => Time.parse("2013-08-01 11:00:00")
            }, A::Article.find(1).as_cache_json)
          end
        end
      end

    end
  end
end