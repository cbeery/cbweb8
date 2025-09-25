namespace :db do

  local_psql_db = 'oel_factory_development'
  local_backup_path = ENV['DB_BACKUP_FOLDER']
  app_name = Rails.application.class.module_parent_name

  desc "Dump local db"
  task dump: :environment do

    dump_file_name = "#{app_name}-#{Util.simple_hypenated_timestamp}.dump"
    dump_file_path = "#{local_backup_path}/#{dump_file_name}"

    `pg_dump -Fc --verbose #{local_psql_db} > '#{dump_file_path}'`
    puts "Dumped to '#{dump_file_path}'"

  end

  desc "Restore local db from a dump"
  task restore: :environment do
    ARGV.each { |a| task a.to_sym do ; end } # Hack to dynamically create rake tasks for the args
    if ARGV[1]
      db_file_path = ARGV[1]
      local_db_file_to_restore = db_file_path
    else

      puts "Latest dumps..."
      files = Dir.glob("#{local_backup_path}/*").max_by(5) {|f| File.mtime(f)}
      files.each_with_index do |file, index|
        puts "#{index+1}: #{file.gsub(local_backup_path,'')}"
      end

      print "Choose file: "
      selected_file_number = STDIN.gets.chomp
      selected_file_index = selected_file_number.to_i
      file_range = (1..files.size)
      if file_range.include? selected_file_index
        local_db_file_to_restore = files[selected_file_index - 1]
      end

    end # if ARGV[1]

    puts "Ok, we are restoring the file '#{local_db_file_to_restore}' to local databse '#{local_psql_db}'..."
    `pg_restore --verbose --clean --no-acl --no-owner -d #{local_psql_db} '#{local_db_file_to_restore}'`

    puts "Restored!"

  end # task restore:

  desc "Display the local dump/restore path"
  task backup_path: :environment do
    puts local_backup_path
  end
  
end
