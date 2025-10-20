namespace :concerts do
  desc "Import concerts from CSV files"
  task import: :environment do
    require 'csv'
    
    puts "Starting concert import..."
    puts "=" * 50
    
    # Import venues
    if File.exist?('tmp/import/venues.csv')
      puts "\nImporting venues..."
      CSV.foreach('tmp/import/venues.csv', headers: true) do |row|
        venue = ConcertVenue.find_or_create_by!(
          name: row['name']
        ) do |v|
          v.city = row['city']
          v.state = row['state']
        end
        puts "  ✓ #{venue.display_name}"
      end
    end
    
    # Import artists
    if File.exist?('tmp/import/artists.csv')
      puts "\nImporting artists..."
      CSV.foreach('tmp/import/artists.csv', headers: true) do |row|
        artist = ConcertArtist.find_or_create_by!(
          name: row['name']
        )
        puts "  ✓ #{artist.name}"
      end
    end
    
    # Import concerts/events
    if File.exist?('tmp/import/events.csv')
      puts "\nImporting concerts..."
      CSV.foreach('tmp/import/events.csv', headers: true) do |row|
        venue = ConcertVenue.find_by(id: row['venue_id'])
        next unless venue
        
        concert = Concert.find_or_create_by!(
          played_on: Date.parse(row['played_on']),
          concert_venue: venue
        )
        puts "  ✓ Concert on #{concert.played_on} at #{venue.name}"
      end
    end
    
    # Import performances
    if File.exist?('tmp/import/performances.csv')
      puts "\nImporting performances..."
      CSV.foreach('tmp/import/performances.csv', headers: true) do |row|
        concert = Concert.find_by(id: row['event_id'])
        artist = ConcertArtist.find_by(id: row['artist_id'])
        
        next unless concert && artist
        
        ConcertPerformance.find_or_create_by!(
          concert: concert,
          concert_artist: artist
        ) do |p|
          p.position = row['position'] || 0
        end
        puts "  ✓ #{artist.name} at concert ##{concert.id}"
      end
    end
    
    puts "\n" + "=" * 50
    puts "Import complete!"
    puts "  Venues: #{ConcertVenue.count}"
    puts "  Artists: #{ConcertArtist.count}"
    puts "  Concerts: #{Concert.count}"
    puts "  Performances: #{ConcertPerformance.count}"
  end
  
  desc "Export legacy data to CSV"
  task export_legacy: :environment do
    require 'csv'
    
    # This would run in your legacy app to export the data
    # Adjust the model names as needed
    
    FileUtils.mkdir_p('tmp/export')
    
    CSV.open('tmp/export/venues.csv', 'w') do |csv|
      csv << ['id', 'name', 'city', 'state']
      Venue.find_each do |venue|
        csv << [venue.id, venue.name, venue.city, venue.state]
      end
    end
    
    CSV.open('tmp/export/artists.csv', 'w') do |csv|
      csv << ['id', 'name']
      Artist.find_each do |artist|
        csv << [artist.id, artist.name]
      end
    end
    
    CSV.open('tmp/export/events.csv', 'w') do |csv|
      csv << ['id', 'played_on', 'venue_id']
      Event.find_each do |event|
        csv << [event.id, event.played_on, event.venue_id]
      end
    end
    
    CSV.open('tmp/export/performances.csv', 'w') do |csv|
      csv << ['event_id', 'artist_id', 'position']
      Performance.find_each do |perf|
        csv << [perf.event_id, perf.artist_id, perf.position]
      end
    end
    
    puts "Export complete! Files saved to tmp/export/"
  end
end
