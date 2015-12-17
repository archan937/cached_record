require_relative "test_helper/coverage"

require "minitest/autorun"
require "mocha/setup"

require "bundler"
Bundler.require :default, :development

def path(path)
  File.expand_path "../../#{path}", __FILE__
end

require_relative "test_helper/setup"
require_relative "test_helper/minitest"
require_relative "test_helper/db"
