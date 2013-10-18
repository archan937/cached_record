require "yaml"

dbconfig = YAML.load_file(path("config/database.yml"))["test"]

ActiveRecord::Base.establish_connection dbconfig
DataMapper.setup :default, dbconfig.merge("adapter" => "mysql")

module AR
  class Article < ActiveRecord::Base
    belongs_to :user
  end
  class User < ActiveRecord::Base
    has_many :articles
  end
end

module DM
  class Article
    include DataMapper::Resource
    storage_names[:default] = "articles"
    property :title, String
    property :content, Text
    property :published_at, DateTime
    property :created_at, DateTime
    property :updated_at, DateTime
    belongs_to :author, :model => "DM::User"
  end
  class User < ActiveRecord::Base
    include DataMapper::Resource
    storage_names[:default] = "users"
    property :name, String
    property :description, String
    property :active, Boolean
    property :created_at, DateTime
    property :updated_at, DateTime
    has n, :articles, :model => "DM::Article"
  end
end