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
    
    # Preload all existing venues, artists, concerts into memory for fast lookups
    existing_venues = ConcertVenue.pluck(:name, :id).to_h
    existing_artists = ConcertArtist.pluck(:name, :id).to_h
    existing_concerts = Concert.joins(:concert_venue)
                               .pluck('concerts.played_on', 'concert_venues.id', 'concerts.id')
                               .map { |date, venue_id, concert_id| [[date, venue_id], concert_id] }
                               .to_h
    
    # Import venues (using bulk insert for new records)
    venues_file = File.join(import_dir, 'venues.csv')
    if File.exist?(venues_file)
      puts "\n📍 Importing venues..."
      new_venues = []
      
      CSV.foreach(venues_file, headers: true) do |row|
        begin
          if existing_venues[row['name']]
            # Venue exists, just map the ID
            venue_map[row['id'].to_i] = existing_venues[row['name']] if row['id']
            puts "  ⚠️  Skipping #{row['name']} - already exists"
          else
            # Collect new venue for bulk insert
            timestamps = {}
            timestamps[:created_at] = row['created_at'] ? DateTime.parse(row['created_at']) : Time.current
            timestamps[:updated_at] = row['updated_at'] ? DateTime.parse(row['updated_at']) : Time.current
            
            new_venues << {
              name: row['name'],
              city: row['city'],
              state: row['state'],
              **timestamps
            }
          end
        rescue => e
          puts "  ✗ Failed to prepare venue '#{row['name']}': #{e.message}"
        end
      end
      
      # Bulk insert new venues
      if new_venues.any?
        result = ConcertVenue.insert_all(new_venues, returning: %w[id name])
        result.rows.each do |id, name|
          existing_venues[name] = id
          puts "  ✓ #{name}"
        end
      end
      
      # Now map legacy IDs
      CSV.foreach(venues_file, headers: true) do |row|
        if row['id'] && existing_venues[row['name']]
          venue_map[row['id'].to_i] = existing_venues[row['name']]
        end
      end
      
      puts "  Processed #{venue_map.size} venues"
    else
      puts "⚠️  Skipping venues - file not found: #{venues_file}"
    end
    
    # Import artists (using bulk insert for new records)
    artists_file = File.join(import_dir, 'artists.csv')
    if File.exist?(artists_file)
      puts "\n🎤 Importing artists..."
      new_artists = []
      
      CSV.foreach(artists_file, headers: true) do |row|
        begin
          if existing_artists[row['name']]
            # Artist exists, just map the ID
            artist_map[row['id'].to_i] = existing_artists[row['name']] if row['id']
            puts "  ⚠️  Skipping #{row['name']} - already exists"
          else
            # Collect new artist for bulk insert
            timestamps = {}
            timestamps[:created_at] = row['created_at'] ? DateTime.parse(row['created_at']) : Time.current
            timestamps[:updated_at] = row['updated_at'] ? DateTime.parse(row['updated_at']) : Time.current
            
            new_artists << {
              name: row['name'],
              **timestamps
            }
          end
        rescue => e
          puts "  ✗ Failed to prepare artist '#{row['name']}': #{e.message}"
        end
      end
      
      # Bulk insert new artists
      if new_artists.any?
        result = ConcertArtist.insert_all(new_artists, returning: %w[id name])
        result.rows.each do |id, name|
          existing_artists[name] = id
          puts "  ✓ #{name}"
        end
      end
      
      # Now map legacy IDs
      CSV.foreach(artists_file, headers: true) do |row|
        if row['id'] && existing_artists[row['name']]
          artist_map[row['id'].to_i] = existing_artists[row['name']]
        end
      end
      
      puts "  Processed #{artist_map.size} artists"
    else
      puts "⚠️  Skipping artists - file not found: #{artists_file}"
    end
    
    # Import concerts/events (using bulk insert for new records)
    events_file = File.join(import_dir, 'events.csv')
    if File.exist?(events_file)
      puts "\n🎵 Importing concerts..."
      new_concerts = []
      
      CSV.foreach(events_file, headers: true) do |row|
        begin
          legacy_venue_id = row['venue_id'].to_i
          venue_id = venue_map[legacy_venue_id]
          
          unless venue_id
            puts "  ✗ Skipping concert - venue not found for legacy ID #{legacy_venue_id}"
            next
          end
          
          played_on = Date.parse(row['played_on'])
          
          if existing_concerts[[played_on, venue_id]]
            # Concert exists, just map the ID
            concert_map[row['id'].to_i] = existing_concerts[[played_on, venue_id]] if row['id']
            puts "  ⚠️  Skipping concert on #{played_on.strftime('%b %d, %Y')} - already exists"
          else
            # Collect new concert for bulk insert
            timestamps = {}
            timestamps[:created_at] = row['created_at'] ? DateTime.parse(row['created_at']) : Time.current
            timestamps[:updated_at] = row['updated_at'] ? DateTime.parse(row['updated_at']) : Time.current
            
            new_concerts << {
              played_on: played_on,
              concert_venue_id: venue_id,
              **timestamps
            }
          end
        rescue => e
          puts "  ✗ Failed to prepare concert: #{e.message}"
        end
      end
      
      # Bulk insert new concerts
      if new_concerts.any?
        result = Concert.insert_all(new_concerts, returning: %w[id played_on concert_venue_id])
        result.rows.each do |id, played_on, venue_id|
          # played_on might come back as a Date or String depending on the adapter
          played_on_date = played_on.is_a?(Date) ? played_on : Date.parse(played_on.to_s)
          existing_concerts[[played_on_date, venue_id.to_i]] = id
          venue = ConcertVenue.find(venue_id)
          puts "  ✓ Concert on #{played_on_date.strftime('%b %d, %Y')} at #{venue.name}"
        end
      end
      
      # Now map legacy IDs
      CSV.foreach(events_file, headers: true) do |row|
        if row['id']
          legacy_venue_id = row['venue_id'].to_i
          venue_id = venue_map[legacy_venue_id]
          played_on = Date.parse(row['played_on'])
          if venue_id && existing_concerts[[played_on, venue_id]]
            concert_map[row['id'].to_i] = existing_concerts[[played_on, venue_id]]
          end
        end
      end
      
      puts "  Processed #{concert_map.size} concerts"
    else
      puts "⚠️  Skipping concerts - file not found: #{events_file}"
    end
    
    # Import performances (using bulk insert)
    performances_file = File.join(import_dir, 'performances.csv')
    if File.exist?(performances_file)
      puts "\n🎸 Importing performances..."
      
      # Preload existing performances
      existing_performances = ConcertPerformance
        .pluck(:concert_id, :concert_artist_id)
        .map { |c_id, a_id| [c_id, a_id] }
        .to_set
      
      new_performances = []
      
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
          
          if existing_performances.include?([concert_id, artist_id])
            puts "  ⚠️  Skipping performance - already exists"
          else
            # Collect new performance for bulk insert
            timestamps = {}
            timestamps[:created_at] = row['created_at'] ? DateTime.parse(row['created_at']) : Time.current
            timestamps[:updated_at] = row['updated_at'] ? DateTime.parse(row['updated_at']) : Time.current
            
            new_performances << {
              concert_id: concert_id,
              concert_artist_id: artist_id,
              position: row['position'] || 0,
              **timestamps
            }
          end
        rescue => e
          puts "  ✗ Failed to prepare performance: #{e.message}"
        end
      end
      
      # Bulk insert new performances
      if new_performances.any?
        ConcertPerformance.insert_all(new_performances)
        puts "  ✓ Imported #{new_performances.size} performances"
      end
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
    
    # Export venues with timestamps
    CSV.open(File.join(export_dir, 'venues.csv'), 'w') do |csv|
      csv << ['id', 'name', 'city', 'state', 'created_at', 'updated_at']
      Venue.find_each do |venue|
        csv << [
          venue.id, 
          venue.name, 
          venue.city, 
          venue.state,
          venue.created_at&.iso8601,
          venue.updated_at&.iso8601
        ]
      end
    end
    puts "✓ Exported #{Venue.count} venues"
    
    # Export artists with timestamps
    CSV.open(File.join(export_dir, 'artists.csv'), 'w') do |csv|
      csv << ['id', 'name', 'created_at', 'updated_at']
      Artist.find_each do |artist|
        csv << [
          artist.id, 
          artist.name,
          artist.created_at&.iso8601,
          artist.updated_at&.iso8601
        ]
      end
    end
    puts "✓ Exported #{Artist.count} artists"
    
    # Export events with timestamps
    CSV.open(File.join(export_dir, 'events.csv'), 'w') do |csv|
      csv << ['id', 'played_on', 'venue_id', 'created_at', 'updated_at']
      Event.find_each do |event|
        csv << [
          event.id, 
          event.played_on, 
          event.venue_id,
          event.created_at&.iso8601,
          event.updated_at&.iso8601
        ]
      end
    end
    puts "✓ Exported #{Event.count} events"
    
    # Export performances with timestamps
    CSV.open(File.join(export_dir, 'performances.csv'), 'w') do |csv|
      csv << ['event_id', 'artist_id', 'position', 'created_at', 'updated_at']
      Performance.find_each do |perf|
        csv << [
          perf.event_id, 
          perf.artist_id, 
          perf.position,
          perf.created_at&.iso8601,
          perf.updated_at&.iso8601
        ]
      end
    end
    puts "✓ Exported #{Performance.count} performances"
    
    puts "\nExport complete! Files saved to #{export_dir}/"
    puts "Copy these files to your new app's tmp/import/ directory"
  end
end
