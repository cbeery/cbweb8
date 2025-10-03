# lib/tasks/spotify_backfill.rake
namespace :spotify do
  desc "Backfill album images for existing tracks"
  task backfill_album_images: :environment do
    service = Sync::SpotifyService.new
    service.send(:ensure_authenticated!)
    
    tracks_without_images = SpotifyTrack.where(album_image_url: nil).where.not(album_id: nil)
    
    puts "Found #{tracks_without_images.count} tracks without album images"
    
    # Process in batches to avoid rate limiting
    tracks_without_images.find_in_batches(batch_size: 20) do |batch|
      album_ids = batch.map(&:album_id).uniq.compact
      
      album_ids.each do |album_id|
        begin
          response = HTTParty.get(
            "https://api.spotify.com/v1/albums/#{album_id}",
            headers: service.send(:spotify_headers)
          )
          
          if response.success?
            album_image = response.dig('images', 1, 'url') || response.dig('images', 0, 'url')
            
            if album_image
              SpotifyTrack.where(album_id: album_id).update_all(album_image_url: album_image)
              puts "  Updated album image for album #{album_id}"
            end
          end
          
          sleep 0.1 # Be nice to Spotify's API
        rescue => e
          puts "  Error fetching album #{album_id}: #{e.message}"
        end
      end
      
      puts "Processed batch of #{batch.size} tracks"
      sleep 1 # Rate limiting between batches
    end
    
    puts "Done!"
  end

  desc "Backfill last_modified_at from track additions"
  task backfill_last_modified: :environment do
    SpotifyPlaylist.find_each do |playlist|
      most_recent = playlist.spotify_playlist_tracks
                            .where.not(added_at: nil)
                            .maximum(:added_at)
      
      if most_recent && playlist.last_modified_at.nil?
        playlist.update_column(:last_modified_at, most_recent)
        puts "Updated #{playlist.name}: last modified #{most_recent}"
      end
    end
    
    puts "Done!"
  end

  desc "Backfill release dates for existing tracks"
  task backfill_release_dates: :environment do
    require 'httparty'
    
    # Initialize Spotify API service
    service = Sync::SpotifyService.new
    
    # Find tracks without release dates
    tracks_to_update = SpotifyTrack.where(release_year: nil).where.not(album_id: nil)
    total = tracks_to_update.count
    
    puts "=" * 60
    puts "Starting release date backfill for #{total} tracks"
    puts "=" * 60
    
    if total == 0
      puts "No tracks need updating!"
      return
    end
    
    updated = 0
    failed = 0
    batch_size = 50
    
    tracks_to_update.find_in_batches(batch_size: batch_size) do |batch|
      # Get unique album IDs from this batch
      album_ids = batch.map(&:album_id).uniq.compact
      
      album_ids.each_slice(20) do |album_slice|
        begin
          # Fetch album details from Spotify API
          response = HTTParty.get(
            "https://api.spotify.com/v1/albums",
            headers: service.send(:spotify_headers),
            query: { ids: album_slice.join(',') }
          )
          
          if response.success?
            albums_data = response.parsed_response['albums']
            
            albums_data.each do |album_data|
              next unless album_data
              
              # Extract release date info
              release_date_string = album_data['release_date']
              release_date_precision = album_data['release_date_precision']
              
              # Parse the release date
              release_date = nil
              release_year = nil
              
              if release_date_string.present?
                case release_date_precision
                when 'day'
                  release_date = Date.parse(release_date_string) rescue nil
                when 'month'
                  release_date = Date.parse("#{release_date_string}-01") rescue nil
                when 'year'
                  release_date = Date.parse("#{release_date_string}-01-01") rescue nil
                end
                
                release_year = release_date&.year || release_date_string.to_s[0..3].to_i
              end
              
              # Update all tracks with this album_id
              tracks_updated = SpotifyTrack.where(album_id: album_data['id']).update_all(
                release_date: release_date,
                release_date_precision: release_date_precision,
                release_year: release_year,
                updated_at: Time.current
              )
              
              updated += tracks_updated
              print "."
            end
          else
            puts "\nAPI Error: #{response.code} - #{response.message}"
            failed += album_slice.length
          end
          
        rescue => e
          puts "\nError processing albums: #{e.message}"
          failed += album_slice.length
        end
        
        # Rate limit protection
        sleep 0.1
      end
    end
    
    puts "\n" + "=" * 60
    puts "BACKFILL COMPLETE"
    puts "=" * 60
    puts "Updated: #{updated} tracks"
    puts "Failed: #{failed} albums"
    puts "=" * 60
  end
  
  desc "Show release year statistics"
  task release_year_stats: :environment do
    puts "=" * 60
    puts "Release Year Statistics"
    puts "=" * 60
    
    total_tracks = SpotifyTrack.count
    tracks_with_year = SpotifyTrack.where.not(release_year: nil).count
    
    puts "\nTotal tracks: #{total_tracks}"
    puts "Tracks with release year: #{tracks_with_year}"
    puts "Missing release year: #{total_tracks - tracks_with_year}"
    puts "Coverage: #{(tracks_with_year.to_f / total_tracks * 100).round(1)}%"
    
    if tracks_with_year > 0
      puts "\n📊 TRACKS BY DECADE:"
      
      decades = SpotifyTrack.where.not(release_year: nil)
                            .group("(release_year / 10) * 10")
                            .count
                            .sort_by { |k, _| k }
      
      decades.each do |decade, count|
        puts "  #{decade}s: #{count} tracks"
      end
      
      puts "\n📅 TOP YEARS:"
      top_years = SpotifyTrack.where.not(release_year: nil)
                              .group(:release_year)
                              .count
                              .sort_by { |_, v| -v }
                              .first(10)
      
      top_years.each do |year, count|
        puts "  #{year}: #{count} tracks"
      end
    end
    
    puts "=" * 60
  end

end