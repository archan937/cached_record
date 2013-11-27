require File.expand_path("../../test_helper", __FILE__)

module GemExt
  class TestRedis < MiniTest::Unit::TestCase

    describe Redis do
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