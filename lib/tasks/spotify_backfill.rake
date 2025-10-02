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

end