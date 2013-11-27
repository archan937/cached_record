#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rake/testtask"

task :default => :test

Rake::TestTask.new do |test|
  test.pattern = "test/**/test_*.rb"
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