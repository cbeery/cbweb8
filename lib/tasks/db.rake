namespace :db do

  local_psql_db = 'cbweb8_development'
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

  # Add these tasks to your existing namespace :db do block

  # Helper method to find the best pg_dump version available
  def find_best_pg_tool(tool_name, minimum_version: nil)
    # Common installation paths for different PostgreSQL versions
    base_paths = [
      '/opt/homebrew/opt',      # Apple Silicon Homebrew
      '/usr/local/opt',          # Intel Mac Homebrew  
      '/usr/lib',                # Linux
      '/usr/local/lib'           # Alternative Linux
    ]
    
    # Check for PostgreSQL versions from 17 down to 14
    # This way we always use the newest available client
    (17.downto(14)).each do |version|
      base_paths.each do |base_path|
        tool_path = "#{base_path}/postgresql@#{version}/bin/#{tool_name}"
        if File.exist?(tool_path)
          if minimum_version.nil? || version >= minimum_version
            puts "   Found #{tool_name} v#{version}"
            return tool_path
          end
        end
        
        # Also check paths without @ notation (Linux often uses this)
        tool_path = "#{base_path}/postgresql/#{version}/bin/#{tool_name}"
        if File.exist?(tool_path)
          if minimum_version.nil? || version >= minimum_version
            puts "   Found #{tool_name} v#{version}"
            return tool_path
          end
        end
      end
    end
    
    # Fall back to system default
    puts "   Using system default #{tool_name}"
    tool_name
  end

  # Get PostgreSQL server version from a database URL
  def get_postgres_version(db_url)
    version_output = `psql "#{db_url}" -t -c "SELECT version();" 2>/dev/null`
    if version_output && version_output.include?('PostgreSQL')
      # Extract major version number (e.g., "PostgreSQL 16.1" -> 16)
      if match = version_output.match(/PostgreSQL (\d+)/)
        return match[1].to_i
      end
    end
    nil
  rescue
    nil
  end

  # Intelligently choose the best pg_dump for the source database
  def pg_dump_for_source(source_url: nil, is_local: false)
    if is_local
      # For local dumps, system default is usually fine
      return 'pg_dump'
    end
    
    if source_url
      # Try to detect the server version
      server_version = get_postgres_version(source_url)
      if server_version
        puts "   Detected PostgreSQL v#{server_version} on remote server"
        # Find a pg_dump that's at least as new as the server
        return find_best_pg_tool('pg_dump', minimum_version: server_version)
      end
    end
    
    # Default: use the newest available pg_dump
    find_best_pg_tool('pg_dump')
  end

  # Intelligently choose the best pg_restore
  def pg_restore_for_destination(dump_created_with_version: nil)
    # pg_restore should ideally match or exceed the pg_dump version used
    if dump_created_with_version
      find_best_pg_tool('pg_restore', minimum_version: dump_created_with_version)
    else
      find_best_pg_tool('pg_restore')
    end
  end

  desc "Push local database to Render (replaces remote database)"
  task push: :environment do
    # Get Render database URL from environment
    render_db_url = ENV['DATABASE_URL'] || ENV['RENDER_DATABASE_URL']
    
    unless render_db_url
      puts "❌ Error: DATABASE_URL or RENDER_DATABASE_URL not found in environment variables"
      puts "Make sure you have the Render database URL configured"
      exit 1
    end
    
    # Parse the Render database name from URL for display
    render_db_name = render_db_url.match(/\/([^?]+)(\?|$)/)[1] rescue "Render database"
    
    puts "⚠️  WARNING: This will replace the Render database with your local database!"
    puts "📤 Source: #{local_psql_db} (local)"
    puts "📥 Target: #{render_db_name} (Render)"
    print "\nAre you sure you want to continue? (yes/no): "
    
    confirmation = STDIN.gets.chomp.downcase
    unless confirmation == 'yes' || confirmation == 'y'
      puts "❌ Push cancelled"
      exit 0
    end
    
    puts "\n🔄 Creating local dump..."
    dump_file_name = "#{app_name}-push-#{Util.simple_hypenated_timestamp}.dump"
    dump_file_path = "#{local_backup_path}/#{dump_file_name}"
    
    # Use appropriate pg_dump for local database
    pg_dump_cmd = pg_dump_for_source(is_local: true)
    
    # Create dump of local database
    dump_result = system("#{pg_dump_cmd} -Fc --verbose --no-acl --no-owner #{local_psql_db} > '#{dump_file_path}'")
    
    unless dump_result
      puts "❌ Failed to create local dump"
      exit 1
    end
    
    puts "✅ Local dump created: #{dump_file_path}"
    puts "\n🔄 Pushing to Render database..."
    
    # Use appropriate pg_restore (newest available)
    pg_restore_cmd = pg_restore_for_destination()
    
    # Restore directly to Render database
    # Using --clean to drop existing objects, --if-exists to avoid errors
    # --no-acl and --no-owner to avoid permission issues
    restore_result = system("#{pg_restore_cmd} --verbose --clean --if-exists --no-acl --no-owner -d '#{render_db_url}' '#{dump_file_path}'")
    
    if restore_result
      puts "✅ Successfully pushed local database to Render!"
      puts "📁 Backup saved at: #{dump_file_path}"
    else
      puts "⚠️  Push completed with warnings (this is often normal)"
      puts "📁 Backup saved at: #{dump_file_path}"
    end
  end

  desc "Pull Render database to local (replaces local database)"
  task pull: :environment do
    # Get Render database URL from environment
    render_db_url = ENV['DATABASE_URL'] || ENV['RENDER_DATABASE_URL']
    
    unless render_db_url
      puts "❌ Error: DATABASE_URL or RENDER_DATABASE_URL not found in environment variables"
      puts "Make sure you have the Render database URL configured"
      exit 1
    end
    
    # Parse the Render database name from URL for display
    render_db_name = render_db_url.match(/\/([^?]+)(\?|$)/)[1] rescue "Render database"
    
    puts "⚠️  WARNING: This will replace your local database with the Render database!"
    puts "📤 Source: #{render_db_name} (Render)"
    puts "📥 Target: #{local_psql_db} (local)"
    print "\nAre you sure you want to continue? (yes/no): "
    
    confirmation = STDIN.gets.chomp.downcase
    unless confirmation == 'yes' || confirmation == 'y'
      puts "❌ Pull cancelled"
      exit 0
    end
    
    puts "\n🔄 Creating backup of Render database..."
    dump_file_name = "#{app_name}-pull-#{Util.simple_hypenated_timestamp}.dump"
    dump_file_path = "#{local_backup_path}/#{dump_file_name}"
    
    # Use appropriate pg_dump for Render database
    pg_dump_cmd = pg_dump_for_source(source_url: render_db_url)
    puts "   Using: #{pg_dump_cmd}"
    
    # Track which version we're using for the dump (for restore compatibility)
    dump_version = pg_dump_cmd.match(/postgresql@(\d+)/) ? $1.to_i : nil
    
    # Create dump from Render database
    dump_result = system("#{pg_dump_cmd} -Fc --verbose --no-acl --no-owner '#{render_db_url}' > '#{dump_file_path}'")
    
    unless dump_result
      puts "❌ Failed to create dump from Render database"
      puts "   This is likely due to PostgreSQL version mismatch."
      puts "   The remote server may be running a newer PostgreSQL version."
      puts "   Try: brew install postgresql@16 (or postgresql@17 for future versions)"
      exit 1
    end
    
    puts "✅ Render dump created: #{dump_file_path}"
    
    # Terminate existing connections to the local database
    puts "\n🔄 Terminating existing connections to local database..."
    ActiveRecord::Base.connection.execute <<-SQL
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = '#{local_psql_db}'
        AND pid <> pg_backend_pid()
        AND state = 'idle';
    SQL
    
    # Disconnect our own connection
    ActiveRecord::Base.connection.disconnect!
    
    puts "🔄 Restoring to local database..."
    
    # Use compatible pg_restore (matching or newer than the pg_dump version used)
    pg_restore_cmd = pg_restore_for_destination(dump_created_with_version: dump_version)
    puts "   Using: #{pg_restore_cmd}"
    
    # Restore to local database
    restore_result = system("#{pg_restore_cmd} --verbose --clean --if-exists --no-acl --no-owner -d #{local_psql_db} '#{dump_file_path}'")
    
    # Reconnect
    ActiveRecord::Base.establish_connection
    
    if restore_result
      puts "✅ Successfully pulled Render database to local!"
      puts "📁 Backup saved at: #{dump_file_path}"
    else
      puts "⚠️  Pull completed with warnings (this is often normal)"
      puts "📁 Backup saved at: #{dump_file_path}"
    end
    
    # Run any pending migrations that might exist in Render but not locally
    puts "\n🔄 Checking for pending migrations..."
    Rake::Task['db:migrate'].invoke
    puts "✅ Database is ready!"
  end

  # Alternative pull method using plain SQL format (if PG16 tools not available)
  desc "Pull Render database using SQL format (version-agnostic fallback)"
  task pull_sql: :environment do
    render_db_url = ENV['DATABASE_URL'] || ENV['RENDER_DATABASE_URL']
    
    unless render_db_url
      puts "❌ Error: DATABASE_URL or RENDER_DATABASE_URL not found in environment variables"
      exit 1
    end
    
    render_db_name = render_db_url.match(/\/([^?]+)(\?|$)/)[1] rescue "Render database"
    
    puts "⚠️  WARNING: This will replace your local database with the Render database!"
    puts "📤 Source: #{render_db_name} (Render)"
    puts "📥 Target: #{local_psql_db} (local)"
    puts "ℹ️  Using SQL format for version compatibility"
    print "\nAre you sure you want to continue? (yes/no): "
    
    confirmation = STDIN.gets.chomp.downcase
    unless confirmation == 'yes' || confirmation == 'y'
      puts "❌ Pull cancelled"
      exit 0
    end
    
    puts "\n🔄 Creating SQL backup of Render database..."
    dump_file_name = "#{app_name}-pull-#{Util.simple_hypenated_timestamp}.sql"
    dump_file_path = "#{local_backup_path}/#{dump_file_name}"
    
    # Use plain SQL format which is more version-flexible
    # Note: --quote-all-identifiers helps with compatibility
    dump_cmd = "pg_dump --verbose --no-acl --no-owner --quote-all-identifiers --if-exists --clean '#{render_db_url}' > '#{dump_file_path}'"
    dump_result = system(dump_cmd)
    
    unless dump_result
      puts "❌ Failed to create dump from Render database"
      puts "   Even SQL format failed - you may need to install newer PostgreSQL client tools:"
      puts "   Check the remote PostgreSQL version and install matching client tools"
      puts "   For example: brew install postgresql@16 or postgresql@17"
      exit 1
    end
    
    puts "✅ Render SQL dump created: #{dump_file_path}"
    
    # Terminate existing connections
    puts "\n🔄 Terminating existing connections to local database..."
    ActiveRecord::Base.connection.execute <<-SQL
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = '#{local_psql_db}'
        AND pid <> pg_backend_pid()
        AND state = 'idle';
    SQL
    
    ActiveRecord::Base.connection.disconnect!
    
    puts "🔄 Restoring SQL to local database..."
    
    # Restore using psql
    restore_result = system("psql -d #{local_psql_db} < '#{dump_file_path}'")
    
    ActiveRecord::Base.establish_connection
    
    if restore_result
      puts "✅ Successfully pulled Render database to local!"
      puts "📁 SQL backup saved at: #{dump_file_path}"
    else
      puts "⚠️  Pull completed with warnings (this is often normal with SQL format)"
      puts "📁 SQL backup saved at: #{dump_file_path}"
    end
    
    puts "\n🔄 Checking for pending migrations..."
    Rake::Task['db:migrate'].invoke
    puts "✅ Database is ready!"
  end
end
