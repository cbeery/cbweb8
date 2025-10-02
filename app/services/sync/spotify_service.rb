require 'httparty'

module Sync
  class SpotifyService < BaseService
    include HTTParty
    base_uri 'https://api.spotify.com/v1'
    
    BATCH_SIZE = 50  # Spotify's max items per request
    
    def initialize(sync_status: nil, broadcast: false)
      super
      @access_token = nil
      @token_expires_at = nil
    end
    
    protected
    
    def source_type
      'spotify'
    end
    
    def fetch_items
      SpotifyPlaylist.all
    end
    
    def process_item(playlist)
      log(:info, "Syncing playlist: #{playlist.name}")
      
      ensure_authenticated!
      
      # Fetch playlist details from Spotify
      playlist_data = fetch_playlist_details(playlist.spotify_id)
      if playlist_data.nil?
        log(:error, "Could not fetch playlist data", playlist_id: playlist.id)
        return :failed
      end
      
      # Update playlist metadata
      update_playlist_metadata(playlist, playlist_data)
      
      # Fetch and sync all tracks
      sync_playlist_tracks(playlist, playlist_data)
      
      # Update calculated fields
      playlist.calculate_runtime!
      playlist.update!(last_synced_at: Time.current)
      
      :updated
    rescue => e
      log(:error, "Failed to sync playlist: #{e.message}", 
          playlist_id: playlist.id, 
          error: e.class.name)
      :failed
    end
    
    def describe_item(playlist)
      "#{playlist.name} (#{playlist.spotify_id})"
    end
    
    private
    
    def ensure_authenticated!
      return if @access_token && @token_expires_at > Time.current
      
      authenticate!
    end
    
    def authenticate!
      log(:info, "Authenticating with Spotify API...")
      
      response = self.class.post(
        'https://accounts.spotify.com/api/token',
        body: {
          grant_type: 'refresh_token',
          refresh_token: ENV['SPOTIFY_REFRESH_TOKEN'],
          client_id: ENV['SPOTIFY_CLIENT_ID'],
          client_secret: ENV['SPOTIFY_CLIENT_SECRET']
        },
        headers: {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      )
      
      if response.success?
        @access_token = response['access_token']
        @token_expires_at = Time.current + response['expires_in'].seconds
        log(:info, "Successfully authenticated with Spotify")
      else
        raise "Failed to authenticate: #{response.body}"
      end
    end
    
    def spotify_headers
      {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json'
      }
    end
    
    def fetch_playlist_details(playlist_id)
      response = self.class.get(
        "/playlists/#{playlist_id}",
        headers: spotify_headers
      )
      
      response.success? ? response.parsed_response : nil
    end
    
    def update_playlist_metadata(playlist, data)
      new_snapshot_id = data['snapshot_id']
      
      # Check if the playlist has been modified since last sync
      playlist_modified = false
      if playlist.snapshot_id.present? && playlist.snapshot_id != new_snapshot_id
        playlist_modified = true
        log(:info, "Playlist modified - snapshot changed", 
            playlist_id: playlist.id,
            old_snapshot: playlist.snapshot_id,
            new_snapshot: new_snapshot_id)
      end
      
      # Also check the most recently added track as a fallback
      # (Sometimes snapshot_id doesn't change for collaborative playlists)
      latest_track_added = nil
      if data.dig('tracks', 'items').present?
        track_dates = data['tracks']['items'].map { |item| 
          item['added_at'] if item['added_at'].present? 
        }.compact
        latest_track_added = track_dates.max
      end
      
      playlist.update!(
        owner_name: data.dig('owner', 'display_name'),
        owner_id: data.dig('owner', 'id'),
        description: data['description'],
        public: data['public'],
        collaborative: data['collaborative'],
        followers_count: data.dig('followers', 'total') || 0,
        image_url: data.dig('images', 0, 'url'),
        previous_snapshot_id: playlist.snapshot_id, # Store the previous snapshot
        snapshot_id: new_snapshot_id,
        last_modified_at: playlist_modified ? Time.current : (playlist.last_modified_at || latest_track_added || Time.current),
        spotify_data: {
          external_urls: data['external_urls'],
          uri: data['uri'],
          href: data['href']
        }
      )
    end
    
    def sync_playlist_tracks(playlist, playlist_data)
      total_tracks = playlist_data.dig('tracks', 'total') || 0
      log(:info, "Fetching #{total_tracks} tracks for playlist")
      
      # Track the most recent track addition
      most_recent_addition = nil
      
      # Clear existing tracks (we'll re-add them with current positions)
      playlist.spotify_playlist_tracks.destroy_all
      
      position = 0
      offset = 0
      
      loop do
        tracks_batch = fetch_playlist_tracks(playlist.spotify_id, offset: offset)
        break if tracks_batch.nil? || tracks_batch['items'].empty?
        
        tracks_batch['items'].each do |item|
          next if item['track'].nil?  # Skip null tracks (deleted from Spotify)
          
          track_data = item['track']
          position += 1
          
          # Track the most recent addition
          if item['added_at'].present?
            added_at = Time.parse(item['added_at'])
            most_recent_addition = added_at if most_recent_addition.nil? || added_at > most_recent_addition
          end
          
          # Find or create the track
          track = find_or_create_track(track_data)
          
          # Create playlist-track association
          playlist.spotify_playlist_tracks.create!(
            spotify_track: track,
            position: position,
            added_at: item['added_at'],
            added_by: item.dig('added_by', 'id')
          )
        end
        
        # Check if we have more tracks to fetch
        break unless tracks_batch['next']
        offset += BATCH_SIZE
      end
      
      # Update last_modified_at if we found a more recent track addition
      if most_recent_addition && (playlist.last_modified_at.nil? || most_recent_addition > playlist.last_modified_at)
        playlist.update!(last_modified_at: most_recent_addition)
        log(:info, "Updated last_modified_at based on track additions", 
            playlist_id: playlist.id,
            last_modified_at: most_recent_addition)
      end
      
      log(:info, "Synced #{position} tracks for playlist")
    end

    def fetch_playlist_tracks(playlist_id, offset: 0)
      response = self.class.get(
        "/playlists/#{playlist_id}/tracks",
        headers: spotify_headers,
        query: {
          limit: BATCH_SIZE,
          offset: offset,
          fields: 'items(track(id,name,artists,album(name,id,images,external_urls),duration_ms,popularity,explicit,external_urls,preview_url,disc_number,track_number,is_local),added_at,added_by.id),next,total'
        }
      )
      
      response.success? ? response.parsed_response : nil
    end
    
    def find_or_create_track(track_data)
      # Skip local files
      return nil if track_data['is_local']
      
      track = SpotifyTrack.find_or_initialize_by(spotify_id: track_data['id'])
      
      # Extract album image URL (Spotify provides multiple sizes, we'll grab the middle one)
      album_image_url = track_data.dig('album', 'images', 1, 'url') || 
                        track_data.dig('album', 'images', 0, 'url')
      
      # Update track details
      track.assign_attributes(
        title: track_data['name'],
        album: track_data.dig('album', 'name'),
        album_id: track_data.dig('album', 'id'),
        album_image_url: album_image_url,  # Add this line
        duration_ms: track_data['duration_ms'],
        popularity: track_data['popularity'],
        explicit: track_data['explicit'],
        disc_number: track_data['disc_number'],
        track_number: track_data['track_number'],
        song_url: track_data.dig('external_urls', 'spotify'),
        album_url: track_data.dig('album', 'external_urls', 'spotify'),
        preview_url: track_data['preview_url'],
        spotify_data: {
          uri: track_data['uri'],
          href: track_data['href']
        }
      )
      
      track.save!
      
      # Sync artists
      sync_track_artists(track, track_data['artists'])
      
      # Optionally fetch audio features
      if ENV['SPOTIFY_FETCH_AUDIO_FEATURES'] == 'true'
        fetch_and_save_audio_features(track)
      end
      
      track
    end
    
    def sync_track_artists(track, artists_data)
      # Clear existing associations
      track.spotify_track_artists.destroy_all
      
      artists_data.each_with_index do |artist_data, index|
        artist = find_or_create_artist(artist_data)
        
        track.spotify_track_artists.create!(
          spotify_artist: artist,
          position: index
        )
      end
    end
    
    def find_or_create_artist(artist_data)
      artist = SpotifyArtist.find_or_initialize_by(spotify_id: artist_data['id'])
      
      # Only update if it's a new record or we have more complete data
      if artist.new_record? || artist.updated_at < 1.week.ago
        artist.assign_attributes(
          name: artist_data['name'],
          spotify_url: artist_data.dig('external_urls', 'spotify'),
          spotify_data: {
            uri: artist_data['uri'],
            href: artist_data['href'],
            type: artist_data['type']
          }
        )
        
        # Fetch additional artist details if new
        if artist.new_record? && artist_data['id'].present?
          fetch_and_update_artist_details(artist)
        end
        
        artist.save!
      end
      
      artist
    end
    
    def fetch_and_update_artist_details(artist)
      response = self.class.get(
        "/artists/#{artist.spotify_id}",
        headers: spotify_headers
      )
      
      if response.success?
        data = response.parsed_response
        artist.assign_attributes(
          followers_count: data.dig('followers', 'total'),
          genres: data['genres'] || [],
          popularity: data['popularity'],
          image_url: data.dig('images', 0, 'url')
        )
      end
    rescue => e
      log(:warn, "Could not fetch artist details: #{e.message}", artist_id: artist.spotify_id)
    end
    
    def fetch_and_save_audio_features(track)
      response = self.class.get(
        "/audio-features/#{track.spotify_id}",
        headers: spotify_headers
      )
      
      if response.success?
        features = response.parsed_response
        track.update!(
          audio_features: {
            acousticness: features['acousticness'],
            danceability: features['danceability'],
            energy: features['energy'],
            instrumentalness: features['instrumentalness'],
            key: features['key'],
            liveness: features['liveness'],
            loudness: features['loudness'],
            mode: features['mode'],
            speechiness: features['speechiness'],
            tempo: features['tempo'],
            time_signature: features['time_signature'],
            valence: features['valence']
          }
        )
      end
    rescue => e
      log(:warn, "Could not fetch audio features: #{e.message}", track_id: track.spotify_id)
    end
  end
end