require File.expand_path("../../test_helper", __FILE__)

module GemExt
  class TestRedis < MiniTest::Test

    describe Redis do
      describe "#set" do
        describe "when passing TTL" do
          it "invokes set, followed with expire" do
            redis = Redis.new
            redis.expects(:set_without_cached_record).with(:foo, :bar, {})
            redis.expects(:expire).with(:foo, 10)
            redis.set :foo, :bar, 10
          end
        end
        describe "when passing options hash" do
          it "invokes set" do
            redis = Redis.new
            redis.expects(:set_without_cached_record).with(:foo, :bar, {:ex => 5})
            redis.set :foo, :bar, {:ex => 5}
          end
        end
      end

      describe "#delete" do
        it "calls del" do
          redis = Redis.new
          redis.expects(:del).with(:foo, :bar)
          redis.delete :foo, :bar
        end
      end
    end

  end
end