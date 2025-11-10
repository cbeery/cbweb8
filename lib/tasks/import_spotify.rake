# lib/tasks/spotify_import.rake
namespace :spotify do
  desc "Import playlists from CSV file (playlist name, playlist URL, made_by, year, month)"
  task :import_from_csv, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails spotify:import_from_csv[path/to/file.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing playlists from #{args[:file_path]}..."
    puts "-" * 50
    
    successful_imports = 0
    failed_imports = 0
    skipped_imports = 0
    errors = []
    
    CSV.foreach(args[:file_path], headers: true, header_converters: :symbol) do |row|
      begin
        # Clean up the data
        name = row[:playlist_name]&.strip
        url = row[:playlist_url]&.strip
        made_by = row[:made_by]&.strip
        year = row[:year]&.to_i
        month = row[:month]&.to_i
        
        # Skip if essential data is missing
        if name.blank? || url.blank?
          puts "⚠️  Skipping row - missing name or URL"
          skipped_imports += 1
          next
        end
        
        # Check for duplicates
        if SpotifyPlaylist.exists?(spotify_url: url)
          puts "⚠️  Skipping '#{name}' - URL already exists"
          skipped_imports += 1
          next
        end
        
        # Construct the date (first day of the month)
        made_on = nil
        if year.present? && year > 0 && month.present? && month > 0
          begin
            made_on = Date.new(year, month, 1)
          rescue ArgumentError => e
            puts "⚠️  Invalid date for '#{name}': #{year}/#{month}"
          end
        end
        
        # Determine if it's a mixtape based on made_by
        is_mixtape = made_by.present? && ['CB', 'RB'].include?(made_by.upcase)
        
        # Create the playlist
        playlist = SpotifyPlaylist.create!(
          name: name,
          spotify_url: url,
          made_by: made_by,
          made_on: made_on,
          mixtape: is_mixtape
        )
        
        puts "✅ Imported: #{name} (#{made_by}, #{made_on&.strftime('%b %Y') || 'no date'})"
        successful_imports += 1
        
      rescue ActiveRecord::RecordInvalid => e
        puts "❌ Failed to import '#{row[:playlist_name]}': #{e.message}"
        errors << "#{row[:playlist_name]}: #{e.message}"
        failed_imports += 1
      rescue => e
        puts "❌ Error importing '#{row[:playlist_name]}': #{e.message}"
        errors << "#{row[:playlist_name]}: #{e.message}"
        failed_imports += 1
      end
    end
    
    puts "-" * 50
    puts "Import Complete!"
    puts "✅ Successful: #{successful_imports}"
    puts "⚠️  Skipped: #{skipped_imports}" if skipped_imports > 0
    puts "❌ Failed: #{failed_imports}" if failed_imports > 0
    
    if errors.any?
      puts "\nErrors:"
      errors.each { |error| puts "  - #{error}" }
    end
    
    if successful_imports > 0
      puts "\n💡 Tip: Run 'rails spotify:sync_all' to fetch track data for the new playlists"
    end
  end
  
  desc "Import playlists from CSV with flexible column names"
  task :import_csv_flexible, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails spotify:import_csv_flexible[path/to/file.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing playlists from #{args[:file_path]}..."
    puts "Detected columns: "
    
    # Read headers to detect column mappings
    csv = CSV.read(args[:file_path], headers: true)
    headers = csv.headers.map(&:to_s).map(&:downcase)
    
    # Flexible column detection
    name_column = headers.find { |h| h.include?('name') || h.include?('playlist') && !h.include?('url') }
    url_column = headers.find { |h| h.include?('url') || h.include?('link') || h.include?('spotify') && h.include?('url') }
    made_by_column = headers.find { |h| h.include?('made') || h.include?('by') || h.include?('creator') || h.include?('owner') }
    year_column = headers.find { |h| h.include?('year') }
    month_column = headers.find { |h| h.include?('month') }
    
    puts "  Name: '#{name_column}'"
    puts "  URL: '#{url_column}'"
    puts "  Made By: '#{made_by_column}'"
    puts "  Year: '#{year_column}'"
    puts "  Month: '#{month_column}'"
    puts "-" * 50
    
    successful_imports = 0
    failed_imports = 0
    skipped_imports = 0
    
    csv.each_with_index do |row, index|
      begin
        row_data = row.to_h.transform_keys { |k| k.to_s.downcase }
        
        name = row_data[name_column]&.strip
        url = row_data[url_column]&.strip
        made_by = row_data[made_by_column]&.strip if made_by_column
        year = row_data[year_column]&.to_i if year_column
        month = row_data[month_column]&.to_i if month_column
        
        # Skip if essential data is missing
        if name.blank? || url.blank?
          puts "⚠️  Row #{index + 2}: Skipping - missing name or URL"
          skipped_imports += 1
          next
        end
        
        # Check for duplicates
        if SpotifyPlaylist.exists?(spotify_url: url)
          puts "⚠️  Row #{index + 2}: '#{name}' - URL already exists"
          skipped_imports += 1
          next
        end
        
        # Construct the date
        made_on = nil
        if year.present? && year > 0 && month.present? && month > 0
          begin
            made_on = Date.new(year, month, 1)
          rescue ArgumentError
            puts "⚠️  Row #{index + 2}: Invalid date for '#{name}'"
          end
        end
        
        # Determine if it's a mixtape
        is_mixtape = made_by.present? && ['CB', 'RB'].include?(made_by.upcase)
        
        playlist = SpotifyPlaylist.create!(
          name: name,
          spotify_url: url,
          made_by: made_by,
          made_on: made_on,
          mixtape: is_mixtape
        )
        
        puts "✅ Row #{index + 2}: #{name}"
        successful_imports += 1
        
      rescue => e
        puts "❌ Row #{index + 2}: Failed - #{e.message}"
        failed_imports += 1
      end
    end
    
    puts "-" * 50
    puts "Import Complete!"
    puts "✅ Successful: #{successful_imports}"
    puts "⚠️  Skipped: #{skipped_imports}" if skipped_imports > 0
    puts "❌ Failed: #{failed_imports}" if failed_imports > 0
  end
  
  desc "Sync all playlists that need syncing"
  task sync_all: :environment do
    playlists_to_sync = SpotifyPlaylist.needs_sync
    
    if playlists_to_sync.empty?
      puts "All playlists are up to date!"
      exit
    end
    
    puts "Found #{playlists_to_sync.count} playlists needing sync"
    
    sync_status = SyncStatus.create!(
      source_type: 'spotify',
      interactive: false,
      metadata: { 
        playlist_count: playlists_to_sync.count,
        triggered_by: 'rake task'
      }
    )
    
    SyncJob.perform_later('Sync::SpotifyService', sync_status.id, broadcast: false)
    
    puts "Sync job queued with ID: #{sync_status.id}"
    puts "Run 'rails solid_queue:start' if not already running"
  end
  
  desc "Generate sample CSV template"
  task generate_csv_template: :environment do
    require 'csv'
    
    filename = "spotify_playlists_template.csv"
    
    CSV.open(filename, "w") do |csv|
      csv << ["playlist_name", "playlist_url", "made_by", "year", "month"]
      csv << ["Summer Vibes 2024", "https://open.spotify.com/playlist/example123", "CB", "2024", "6"]
      csv << ["Workout Mix", "https://open.spotify.com/playlist/example456", "RB", "2024", "7"]
      csv << ["Chill Evening", "https://open.spotify.com/playlist/example789", "", "2024", "8"]
    end
    
    puts "Generated template file: #{filename}"
    puts "Edit this file with your playlist data, then run:"
    puts "  rails spotify:import_from_csv[#{filename}]"
  end
end
