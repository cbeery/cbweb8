namespace :spotify do
  desc "Clean up orphaned tracks and artists"
  task cleanup_orphans: :environment do
    puts "=" * 60
    puts "Starting Spotify orphan cleanup..."
    puts "=" * 60
    
    # Store initial counts for reporting
    initial_track_count = SpotifyTrack.count
    initial_artist_count = SpotifyArtist.count
    
    # Find and delete orphaned tracks (tracks not on any playlist)
    orphaned_tracks = SpotifyTrack.orphaned
    orphaned_track_count = orphaned_tracks.count
    
    if orphaned_track_count > 0
      puts "\n📀 Found #{orphaned_track_count} orphaned tracks:"
      
      # Show a sample of what will be deleted
      orphaned_tracks.limit(10).each do |track|
        puts "  - #{track.title} by #{track.artist_text}"
      end
      puts "  ... and #{orphaned_track_count - 10} more" if orphaned_track_count > 10
      
      print "\nDeleting orphaned tracks... "
      orphaned_tracks.destroy_all
      puts "✓"
    else
      puts "\n✓ No orphaned tracks found"
    end
    
    # Find and delete orphaned artists (artists with no tracks)
    orphaned_artists = SpotifyArtist.orphaned
    orphaned_artist_count = orphaned_artists.count
    
    if orphaned_artist_count > 0
      puts "\n🎤 Found #{orphaned_artist_count} orphaned artists:"
      
      # Show a sample of what will be deleted
      orphaned_artists.limit(10).each do |artist|
        puts "  - #{artist.name}"
      end
      puts "  ... and #{orphaned_artist_count - 10} more" if orphaned_artist_count > 10
      
      print "\nDeleting orphaned artists... "
      orphaned_artists.destroy_all
      puts "✓"
    else
      puts "\n✓ No orphaned artists found"
    end
    
    # Summary
    puts "\n" + "=" * 60
    puts "CLEANUP COMPLETE"
    puts "=" * 60
    puts "Tracks:  #{initial_track_count} → #{SpotifyTrack.count} (removed #{orphaned_track_count})"
    puts "Artists: #{initial_artist_count} → #{SpotifyArtist.count} (removed #{orphaned_artist_count})"
    puts "=" * 60
  end
  
  desc "Dry run: Show what would be cleaned up without deleting"
  task cleanup_orphans_dry_run: :environment do
    puts "=" * 60
    puts "DRY RUN - No records will be deleted"
    puts "=" * 60
    
    orphaned_tracks = SpotifyTrack.orphaned
    orphaned_track_count = orphaned_tracks.count
    
    puts "\n📀 Orphaned Tracks (#{orphaned_track_count}):"
    if orphaned_track_count > 0
      orphaned_tracks.limit(25).each do |track|
        puts "  - #{track.title} by #{track.artist_text}"
        puts "    Album: #{track.album}" if track.album.present?
      end
      puts "  ... and #{orphaned_track_count - 25} more" if orphaned_track_count > 25
    else
      puts "  None found"
    end
    
    puts "\n" + "-" * 40
    
    orphaned_artists = SpotifyArtist.orphaned
    orphaned_artist_count = orphaned_artists.count
    
    puts "\n🎤 Orphaned Artists (#{orphaned_artist_count}):"
    if orphaned_artist_count > 0
      orphaned_artists.limit(25).each do |artist|
        puts "  - #{artist.name}"
        puts "    Genres: #{artist.genre_list}" if artist.genre_list.present?
      end
      puts "  ... and #{orphaned_artist_count - 25} more" if orphaned_artist_count > 25
    else
      puts "  None found"
    end
    
    puts "\n" + "=" * 60
    puts "To actually delete these records, run:"
    puts "  rails spotify:cleanup_orphans"
    puts "=" * 60
  end
  
  desc "Show statistics about playlist/track/artist relationships"
  task stats: :environment do
    puts "=" * 60
    puts "Spotify Database Statistics"
    puts "=" * 60
    
    # Basic counts
    puts "\n📊 TOTALS:"
    puts "  Playlists: #{SpotifyPlaylist.count}"
    puts "  Tracks:    #{SpotifyTrack.count}"
    puts "  Artists:   #{SpotifyArtist.count}"
    
    # Playlist breakdown
    puts "\n📚 PLAYLISTS:"
    puts "  Mixtapes:     #{SpotifyPlaylist.mixtapes.count}"
    puts "  Non-mixtapes: #{SpotifyPlaylist.non_mixtapes.count}"
    puts "  Synced:       #{SpotifyPlaylist.where.not(last_synced_at: nil).count}"
    puts "  Never synced: #{SpotifyPlaylist.where(last_synced_at: nil).count}"
    
    # Track sharing
    puts "\n🎵 TRACK SHARING:"
    tracks_on_single = SpotifyTrack.on_single_playlist.count
    tracks_on_multiple = SpotifyTrack.on_multiple_playlists.count
    orphaned_tracks = SpotifyTrack.orphaned.count
    
    puts "  On 1 playlist:        #{tracks_on_single}"
    puts "  On multiple playlists: #{tracks_on_multiple}"
    puts "  Orphaned (no playlist): #{orphaned_tracks}"
    
    # Most shared tracks
    if tracks_on_multiple > 0
      puts "\n  Most shared tracks:"
      SpotifyTrack.joins(:spotify_playlist_tracks)
                  .group('spotify_tracks.id')
                  .order('COUNT(spotify_playlist_tracks.id) DESC')
                  .limit(5)
                  .pluck('spotify_tracks.title', 'spotify_tracks.artist_text', 'COUNT(spotify_playlist_tracks.id)')
                  .each do |title, artist, count|
        puts "    • #{title} by #{artist} (#{count} playlists)"
      end
    end
    
    # Artist distribution
    puts "\n🎤 ARTIST DISTRIBUTION:"
    artists_on_single = SpotifyArtist.on_single_track.count
    artists_on_multiple = SpotifyArtist.on_multiple_tracks.count
    orphaned_artists = SpotifyArtist.orphaned.count
    
    puts "  On 1 track:        #{artists_on_single}"
    puts "  On multiple tracks: #{artists_on_multiple}"
    puts "  Orphaned (no tracks): #{orphaned_artists}"
    
    # Most prolific artists
    if artists_on_multiple > 0
      puts "\n  Most prolific artists:"
      SpotifyArtist.joins(:spotify_track_artists)
                   .group('spotify_artists.id')
                   .order('COUNT(spotify_track_artists.id) DESC')
                   .limit(5)
                   .pluck('spotify_artists.name', 'COUNT(spotify_track_artists.id)')
                   .each do |name, count|
        puts "    • #{name} (#{count} tracks)"
      end
    end
    
    # Storage estimate
    puts "\n💾 STORAGE ESTIMATE:"
    track_size = SpotifyTrack.count * 5 # Rough KB per track
    artist_size = SpotifyArtist.count * 2 # Rough KB per artist
    playlist_size = SpotifyPlaylist.count * 3 # Rough KB per playlist
    total_size_kb = track_size + artist_size + playlist_size
    total_size_mb = total_size_kb / 1024.0
    
    puts "  Estimated database size: ~#{total_size_mb.round(2)} MB"
    if orphaned_tracks > 0 || orphaned_artists > 0
      orphan_size_kb = (orphaned_tracks * 5) + (orphaned_artists * 2)
      orphan_size_mb = orphan_size_kb / 1024.0
      puts "  Reclaimable from orphans: ~#{orphan_size_mb.round(2)} MB"
    end
    
    puts "\n" + "=" * 60
  end
  
  desc "Find tracks that appear on only one playlist (candidates for deletion if that playlist is deleted)"
  task vulnerable_tracks: :environment do
    puts "=" * 60
    puts "Tracks on Only One Playlist"
    puts "(These would become orphans if their playlist is deleted)"
    puts "=" * 60
    
    vulnerable_tracks = SpotifyTrack.on_single_playlist
                                   .includes(:spotify_playlists)
    
    count = vulnerable_tracks.count
    puts "\nFound #{count} vulnerable tracks\n\n"
    
    if count > 0
      # Group by playlist for better visibility
      by_playlist = {}
      vulnerable_tracks.each do |track|
        playlist = track.spotify_playlists.first
        by_playlist[playlist] ||= []
        by_playlist[playlist] << track
      end
      
      by_playlist.sort_by { |playlist, _| playlist.name }.each do |playlist, tracks|
        puts "📁 #{playlist.name} (#{tracks.count} exclusive tracks)"
        tracks.first(5).each do |track|
          puts "   - #{track.title} by #{track.artist_text}"
        end
        puts "   ... and #{tracks.count - 5} more" if tracks.count > 5
        puts ""
      end
    end
  end
  
  desc "Clean up orphans for a specific playlist before deleting it"
  task :cleanup_playlist_orphans, [:playlist_id] => :environment do |task, args|
    unless args[:playlist_id]
      puts "Usage: rails spotify:cleanup_playlist_orphans[playlist_id]"
      exit 1
    end
    
    playlist = SpotifyPlaylist.find_by(id: args[:playlist_id])
    unless playlist
      puts "Playlist with ID #{args[:playlist_id]} not found"
      exit 1
    end
    
    puts "=" * 60
    puts "Analyzing playlist: #{playlist.name}"
    puts "=" * 60
    
    # Find tracks that would become orphans
    vulnerable_track_ids = playlist.spotify_tracks
                                  .joins(:spotify_playlist_tracks)
                                  .group('spotify_tracks.id')
                                  .having('COUNT(DISTINCT spotify_playlist_tracks.spotify_playlist_id) = 1')
                                  .pluck(:id)
    
    if vulnerable_track_ids.any?
      vulnerable_tracks = SpotifyTrack.where(id: vulnerable_track_ids)
      puts "\n🎵 #{vulnerable_tracks.count} tracks will become orphans:"
      vulnerable_tracks.limit(10).each do |track|
        puts "  - #{track.title} by #{track.artist_text}"
      end
      puts "  ..." if vulnerable_tracks.count > 10
    else
      puts "\n✓ No tracks will become orphans"
    end
    
    # Find artists that would become orphans
    artist_ids = SpotifyArtist.joins(:spotify_tracks)
                              .where(spotify_tracks: { id: vulnerable_track_ids })
                              .distinct
                              .pluck(:id)
    
    vulnerable_artist_ids = []
    artist_ids.each do |artist_id|
      other_tracks = SpotifyTrack.joins(:spotify_artists)
                                 .where(spotify_artists: { id: artist_id })
                                 .where.not(id: vulnerable_track_ids)
      vulnerable_artist_ids << artist_id if other_tracks.empty?
    end
    
    if vulnerable_artist_ids.any?
      vulnerable_artists = SpotifyArtist.where(id: vulnerable_artist_ids)
      puts "\n🎤 #{vulnerable_artists.count} artists will become orphans:"
      vulnerable_artists.limit(10).each do |artist|
        puts "  - #{artist.name}"
      end
      puts "  ..." if vulnerable_artists.count > 10
    else
      puts "\n✓ No artists will become orphans"
    end
    
    puts "\n" + "=" * 60
  end
end
