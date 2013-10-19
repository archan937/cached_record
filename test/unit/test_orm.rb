require File.expand_path("../../test_helper", __FILE__)

module Unit
  class TestORM < MiniTest::Unit::TestCase

    class A
      include CachedRecord::ORM
    end

    describe CachedRecord::ORM do
      describe "when extended within a class" do
        it "requires an implemented `uncached` method" do
          assert_raises NotImplementedError do
            A.uncached 1
          end
        end
        it "requires an implemented `as_cache_json` method" do
          assert_raises NotImplementedError do
            A.new.as_cache_json
          end
        end
        it "returns a cache JSON string" do
          hash = mock
          hash.expects(:as_json)
          a = A.new
          a.expects(:as_cache_json).returns(hash)
          a.to_cache_json
        end
      end
    end

  end
end