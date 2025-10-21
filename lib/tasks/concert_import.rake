# lib/tasks/concert_import.rake
namespace :concerts do
  desc "Import concerts from CSV file (played_on, venue_name, venue_city, venue_state, artist_names)"
  task :import_from_csv, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails concerts:import_from_csv[path/to/file.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing concerts from #{args[:file_path]}..."
    puts "-" * 50
    
    successful_imports = 0
    failed_imports = 0
    skipped_imports = 0
    errors = []
    
    CSV.foreach(args[:file_path], headers: true, header_converters: :symbol) do |row|
      begin
        # Clean up the data
        played_on_str = row[:played_on]&.strip
        venue_name = row[:venue_name]&.strip
        venue_city = row[:venue_city]&.strip
        venue_state = row[:venue_state]&.strip
        artist_names_str = row[:artist_names]&.strip
        notes = row[:notes]&.strip
        
        # Skip if essential data is missing
        if played_on_str.blank? || venue_name.blank?
          puts "⚠️  Skipping row - missing date or venue"
          skipped_imports += 1
          next
        end
        
        # Parse the date
        begin
          played_on = Date.parse(played_on_str)
        rescue ArgumentError => e
          puts "⚠️  Invalid date '#{played_on_str}': #{e.message}"
          skipped_imports += 1
          next
        end
        
        # Find or create venue
        venue = ConcertVenue.find_or_create_by!(name: venue_name) do |v|
          v.city = venue_city
          v.state = venue_state
        end
        
        # Check for duplicate concert
        if Concert.exists?(played_on: played_on, concert_venue: venue)
          puts "⚠️  Skipping - Concert already exists on #{played_on} at #{venue_name}"
          skipped_imports += 1
          next
        end
        
        # Create the concert
        concert = Concert.create!(
          played_on: played_on,
          concert_venue: venue,
          notes: notes
        )
        
        # Add artists if provided
        if artist_names_str.present?
          # Split by common delimiters (comma, semicolon, pipe)
          artist_names = artist_names_str.split(/[,;|]/).map(&:strip)
          
          artist_names.each_with_index do |artist_name, index|
            next if artist_name.blank?
            
            artist = ConcertArtist.find_or_create_by!(name: artist_name)
            ConcertPerformance.create!(
              concert: concert,
              concert_artist: artist,
              position: index + 1
            )
          end
        end
        
        artists_text = concert.concert_artists.any? ? 
          " with #{concert.concert_artists.pluck(:name).join(', ')}" : ""
        puts "✅ Imported: #{played_on.strftime('%b %d, %Y')} at #{venue.display_name}#{artists_text}"
        successful_imports += 1
        
      rescue ActiveRecord::RecordInvalid => e
        puts "❌ Failed to import concert: #{e.message}"
        errors << "Row #{CSV.lineno}: #{e.message}"
        failed_imports += 1
      rescue => e
        puts "❌ Error importing concert: #{e.message}"
        errors << "Row #{CSV.lineno}: #{e.message}"
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
  end
  
  desc "Import legacy concert data from multiple CSV files"
  task import_legacy: :environment do
    puts "Starting legacy concert import..."
    puts "=" * 50
    
    import_dir = 'tmp/import'
    unless Dir.exist?(import_dir)
      puts "❌ Error: Directory #{import_dir} does not exist"
      puts "Create the directory and add your CSV files:"
      puts "  - venues.csv"
      puts "  - artists.csv"
      puts "  - events.csv"
      puts "  - performances.csv"
      exit
    end
    
    # Track ID mappings for legacy data
    venue_map = {}
    artist_map = {}
    concert_map = {}
    
    # Import venues
    venues_file = File.join(import_dir, 'venues.csv')
    if File.exist?(venues_file)
      puts "\n📍 Importing venues..."
      CSV.foreach(venues_file, headers: true) do |row|
        begin
          venue = ConcertVenue.find_or_create_by!(name: row['name']) do |v|
            v.city = row['city']
            v.state = row['state']
          end
          venue_map[row['id'].to_i] = venue.id if row['id']
          puts "  ✓ #{venue.display_name}"
        rescue => e
          puts "  ✗ Failed to import venue '#{row['name']}': #{e.message}"
        end
      end
      puts "  Imported #{venue_map.size} venues"
    else
      puts "⚠️  Skipping venues - file not found: #{venues_file}"
    end
    
    # Import artists
    artists_file = File.join(import_dir, 'artists.csv')
    if File.exist?(artists_file)
      puts "\n🎤 Importing artists..."
      CSV.foreach(artists_file, headers: true) do |row|
        begin
          artist = ConcertArtist.find_or_create_by!(name: row['name'])
          artist_map[row['id'].to_i] = artist.id if row['id']
          puts "  ✓ #{artist.name}"
        rescue => e
          puts "  ✗ Failed to import artist '#{row['name']}': #{e.message}"
        end
      end
      puts "  Imported #{artist_map.size} artists"
    else
      puts "⚠️  Skipping artists - file not found: #{artists_file}"
    end
    
    # Import concerts/events
    events_file = File.join(import_dir, 'events.csv')
    if File.exist?(events_file)
      puts "\n🎵 Importing concerts..."
      CSV.foreach(events_file, headers: true) do |row|
        begin
          legacy_venue_id = row['venue_id'].to_i
          venue_id = venue_map[legacy_venue_id]
          
          unless venue_id
            puts "  ✗ Skipping concert - venue not found for legacy ID #{legacy_venue_id}"
            next
          end
          
          venue = ConcertVenue.find(venue_id)
          played_on = Date.parse(row['played_on'])
          
          concert = Concert.find_or_create_by!(
            played_on: played_on,
            concert_venue: venue
          )
          
          concert_map[row['id'].to_i] = concert.id if row['id']
          puts "  ✓ Concert on #{played_on.strftime('%b %d, %Y')} at #{venue.name}"
        rescue => e
          puts "  ✗ Failed to import concert: #{e.message}"
        end
      end
      puts "  Imported #{concert_map.size} concerts"
    else
      puts "⚠️  Skipping concerts - file not found: #{events_file}"
    end
    
    # Import performances
    performances_file = File.join(import_dir, 'performances.csv')
    if File.exist?(performances_file)
      puts "\n🎸 Importing performances..."
      performance_count = 0
      CSV.foreach(performances_file, headers: true) do |row|
        begin
          legacy_concert_id = row['event_id'].to_i
          legacy_artist_id = row['artist_id'].to_i
          
          concert_id = concert_map[legacy_concert_id]
          artist_id = artist_map[legacy_artist_id]
          
          unless concert_id && artist_id
            puts "  ✗ Skipping performance - concert or artist not found"
            next
          end
          
          performance = ConcertPerformance.find_or_create_by!(
            concert_id: concert_id,
            concert_artist_id: artist_id
          ) do |p|
            p.position = row['position'] || 0
          end
          
          performance_count += 1
          concert = Concert.find(concert_id)
          artist = ConcertArtist.find(artist_id)
          puts "  ✓ #{artist.name} at concert on #{concert.played_on.strftime('%b %d, %Y')}"
        rescue => e
          puts "  ✗ Failed to import performance: #{e.message}"
        end
      end
      puts "  Imported #{performance_count} performances"
    else
      puts "⚠️  Skipping performances - file not found: #{performances_file}"
    end
    
    puts "\n" + "=" * 50
    puts "Import complete!"
    puts "  Venues: #{ConcertVenue.count}"
    puts "  Artists: #{ConcertArtist.count}"
    puts "  Concerts: #{Concert.count}"
    puts "  Performances: #{ConcertPerformance.count}"
  end
  
  desc "Generate sample CSV template for concert import"
  task generate_csv_template: :environment do
    require 'csv'
    
    filename = "concerts_template.csv"
    
    CSV.open(filename, "w") do |csv|
      csv << ["played_on", "venue_name", "venue_city", "venue_state", "artist_names", "notes"]
      csv << ["2024-07-15", "The Fillmore", "San Francisco", "CA", "The National, Lucy Dacus", "Great show!"]
      csv << ["2024-08-20", "Red Rocks Amphitheatre", "Morrison", "CO", "Bon Iver", ""]
      csv << ["2024-09-10", "9:30 Club", "Washington", "DC", "Japanese Breakfast, The Linda Lindas", "Sold out"]
    end
    
    puts "Generated template file: #{filename}"
    puts "Edit this file with your concert data, then run:"
    puts "  rails concerts:import_from_csv[#{filename}]"
  end
  
  desc "Export legacy data from old database (run this in your legacy app)"
  task export_legacy_data: :environment do
    require 'csv'
    
    export_dir = 'tmp/export'
    FileUtils.mkdir_p(export_dir)
    
    # Export venues
    CSV.open(File.join(export_dir, 'venues.csv'), 'w') do |csv|
      csv << ['id', 'name', 'city', 'state']
      Venue.find_each do |venue|
        csv << [venue.id, venue.name, venue.city, venue.state]
      end
    end
    puts "✓ Exported #{Venue.count} venues"
    
    # Export artists
    CSV.open(File.join(export_dir, 'artists.csv'), 'w') do |csv|
      csv << ['id', 'name']
      Artist.find_each do |artist|
        csv << [artist.id, artist.name]
      end
    end
    puts "✓ Exported #{Artist.count} artists"
    
    # Export events
    CSV.open(File.join(export_dir, 'events.csv'), 'w') do |csv|
      csv << ['id', 'played_on', 'venue_id']
      Event.find_each do |event|
        csv << [event.id, event.played_on, event.venue_id]
      end
    end
    puts "✓ Exported #{Event.count} events"
    
    # Export performances
    CSV.open(File.join(export_dir, 'performances.csv'), 'w') do |csv|
      csv << ['event_id', 'artist_id', 'position']
      Performance.find_each do |perf|
        csv << [perf.event_id, perf.artist_id, perf.position]
      end
    end
    puts "✓ Exported #{Performance.count} performances"
    
    puts "\nExport complete! Files saved to #{export_dir}/"
    puts "Copy these files to your new app's tmp/import/ directory"
  end
end