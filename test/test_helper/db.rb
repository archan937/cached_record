if Dir.pwd == File.expand_path("../../..", __FILE__)
  require "yaml"
  config = YAML.load_file(File.expand_path("../../../config/database.yml", __FILE__))["test"]
  host, port, user, password, database = config.values_at "host", "port", "username", "password", "database"
  `#{
    [
      "mysqldump",
     ("-h #{host}" unless host.blank?), ("-P #{port}" unless port.blank?),
      "-u #{user}", ("-p#{password}" unless password.blank?),
      "--compact --no-create-db --add-drop-table --skip-lock-tables",
      "#{database} > ./db/cached_record.sql"
    ].compact.join(" ")
  }`
end