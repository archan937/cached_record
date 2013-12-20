require "bundler"
Bundler.require :default, :development

require "active_record"

dbconfig = YAML.load_file(File.expand_path("../../config/database.yml", __FILE__))["development"]
ActiveRecord::Base.establish_connection dbconfig
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = :local

CachedRecord.setup :redis

module Cached
  class Article < ActiveRecord::Base
    self.table_name = "articles"
    belongs_to :author, :class_name => "Cached::User", :foreign_key => "author_id"
    has_many :comments, :class_name => "Cached::Comment", :foreign_key => "article_id"
    as_cache :only => [:title], :include => [:author, :comments]
  end

  class User < ActiveRecord::Base
    self.table_name = "users"
    has_one :foo, :class_name => "Cached::Article", :foreign_key => "foo_id"
    as_cache :only => [:name], :include => [:foo]
  end

  class Comment < ActiveRecord::Base
    self.table_name = "comments"
    belongs_to :article, :class_name => "Cached::Article", :foreign_key => "article_id"
    belongs_to :poster, :class_name => "Cached::User", :foreign_key => "poster_id"
    as_cache :only => [:content], :include => [:poster]
  end
end

module Memoized
  class Article < ActiveRecord::Base
    self.table_name = "articles"
    belongs_to :author, :class_name => "Memoized::User", :foreign_key => "author_id"
    has_many :comments, :class_name => "Memoized::Comment", :foreign_key => "article_id"
    as_memoized_cache :only => [:title], :include => [:author, :comments]
  end

  class User < ActiveRecord::Base
    self.table_name = "users"
    has_one :foo, :class_name => "Memoized::Article", :foreign_key => "foo_id"
    as_memoized_cache :only => [:name], :include => [:foo]
  end

  class Comment < ActiveRecord::Base
    self.table_name = "comments"
    belongs_to :article, :class_name => "Memoized::Article", :foreign_key => "article_id"
    belongs_to :poster, :class_name => "Memoized::User", :foreign_key => "poster_id"
    as_memoized_cache :only => [:content], :include => [:poster]
  end
end

module Retained
  class Article < ActiveRecord::Base
    self.table_name = "articles"
    belongs_to :author, :class_name => "Retained::User", :foreign_key => "author_id"
    has_many :comments, :class_name => "Retained::Comment", :foreign_key => "article_id"
    as_memoized_cache :only => [:title], :include => [:author, :comments], :retain => 10.seconds
  end

  class User < ActiveRecord::Base
    self.table_name = "users"
    has_one :foo, :class_name => "Retained::Article", :foreign_key => "foo_id"
    as_memoized_cache :only => [:name], :include => [:foo], :retain => 10.seconds
  end

  class Comment < ActiveRecord::Base
    self.table_name = "comments"
    belongs_to :article, :class_name => "Retained::Article", :foreign_key => "article_id"
    belongs_to :poster, :class_name => "Retained::User", :foreign_key => "poster_id"
    as_memoized_cache :only => [:content], :include => [:poster], :retain => 10.seconds
  end
end