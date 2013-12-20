#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rake/testtask"

task :default => :test

Rake::TestTask.new do |test|
  test.pattern = "test/**/test_*.rb"
end

task :benchmark do
  require_relative "benchmark/setup"

  def benchmark(description, count, interval)
    Redis.new.flushdb
    puts "Benchmarking #{description} (#{count} times)"
    puts "-> [#{"." * 100}] 0.0% in 0.0s"
    t = Time.now
    count.times do |i|
      if i % interval == (interval - 1)
        print "\e[A\e[K"
        percentage = (i / count.to_f) * 100
        puts "-> [#{("+" * percentage.ceil).ljust(100, ".")}] #{"%.1f" % percentage}% in #{"%.2f" % (Time.now - t)}s"
      end
      yield
    end
  end

  count = 5000
  benchmark "uncached instances", count, 10 do
    article = Cached::Article.find 1
    article.author.foo
    article.comments[0].poster.foo
    article.comments[1].poster.foo
  end
  benchmark "cached instances", count, 10 do
    article = Cached::Article.cached 1
    article.author.foo
    article.comments[0].poster.foo
    article.comments[1].poster.foo
  end
  benchmark "memoized instances", count, 50 do
    article = Memoized::Article.cached 1
    article.author.foo
    article.comments[0].poster.foo
    article.comments[1].poster.foo
  end
  benchmark "retained instances", count, 50 do
    article = Retained::Article.cached 1
    article.author.foo
    article.comments[0].poster.foo
    article.comments[1].poster.foo
  end

  count = 150000
  benchmark "memoized instances", count, 50  do Memoized::Article.cached 1 end
  benchmark "retained instances", count, 100 do Retained::Article.cached 1 end

  puts "Done."
end

namespace :db do
  task :install do
    require "bundler"
    Bundler.require
    require "yaml"
    require "active_record"

    %w(development test).each do |environment|
      puts "Installing #{environment} database..."
      dbconfig = YAML.load_file(File.expand_path("../config/database.yml", __FILE__))[environment]
      host, port, user, password, database = dbconfig.values_at *%w(host port user password database)
      options = {:charset => "utf8", :collation => "utf8_unicode_ci"}

      ActiveRecord::Base.establish_connection dbconfig.merge("database" => nil)
      ActiveRecord::Base.connection.create_database dbconfig["database"], options

      `#{
        [
          "mysql",
         ("-h #{host}" unless host.blank?), ("-P #{port}" unless port.blank?),
          "-u #{user || "root"}", ("-p#{password}" unless password.blank?),
          "#{database} < db/cached_record.sql"
        ].compact.join(" ")
      }`
    end

    puts "Done."
  end
end