$:.unshift File.expand_path("../../lib", __FILE__)

require_relative "test_helper/coverage"

require "minitest/autorun"
require "mocha/setup"

def path(path)
  File.expand_path "../../#{path}", __FILE__
end

require "bundler"
Bundler.require :default, :test
require_relative "test_helper/setup"

class MiniTest::Unit::TestCase
  def teardown
    Redis.new.flushdb
    Dalli::Client.new.flush
    CachedRecord::Cache.clear!
  end
end