require "yaml"

dbconfig = YAML.load_file(File.expand_path("../../config/database.yml", __FILE__))["development"]
ActiveRecord::Base.establish_connection dbconfig

class Article < ActiveRecord::Base
  belongs_to :user
end

class User < ActiveRecord::Base
  has_many :articles
end