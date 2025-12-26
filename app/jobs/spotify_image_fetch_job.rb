# Fetches an image from Spotify for a TopScrobbleImage record
# Uses Spotify Search API to find artists/albums/tracks by name
class SpotifyImageFetchJob < ApplicationJob
  queue_as :default

  # Retry once on network errors, then give up
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 5.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(top_scrobble_image_id)
    @image_record = TopScrobbleImage.find(top_scrobble_image_id)

    # Skip if already processed
    return unless @image_record.pending?

    ensure_authenticated!

    case @image_record.category
    when 'artist'
      fetch_artist_image
    when 'album'
      fetch_album_image
    when 'track'
      fetch_track_image
    end
  rescue StandardError => e
    Rails.logger.error("SpotifyImageFetchJob failed for #{top_scrobble_image_id}: #{e.message}")
    @image_record&.mark_not_found!
  end

  private

  def fetch_artist_image
    results = search_spotify(type: 'artist', query: @image_record.artist)
    artists = results.dig('artists', 'items') || []

    # Find best match
    artist = find_best_match(artists, @image_record.artist, name_key: 'name')

    if artist && artist['images'].present?
      # Prefer medium-sized image (usually index 1), fallback to first
      image_url = artist.dig('images', 1, 'url') || artist.dig('images', 0, 'url')
      @image_record.mark_found!(url: image_url, spotify_id: artist['id'])
    else
      @image_record.mark_not_found!
    end
  end

  def fetch_album_image
    # Search with artist name for better matching
    query = "#{@image_record.name} artist:#{@image_record.artist}"
    results = search_spotify(type: 'album', query: query)
    albums = results.dig('albums', 'items') || []

    # Find best match by album name
    album = find_best_match(albums, @image_record.name, name_key: 'name')

    if album && album['images'].present?
      image_url = album.dig('images', 1, 'url') || album.dig('images', 0, 'url')
      @image_record.mark_found!(url: image_url, spotify_id: album['id'])
    else
      @image_record.mark_not_found!
    end
  end

  def fetch_track_image
    # Search with artist name for better matching
    query = "#{@image_record.name} artist:#{@image_record.artist}"
    results = search_spotify(type: 'track', query: query)
    tracks = results.dig('tracks', 'items') || []

    # Find best match by track name
    track = find_best_match(tracks, @image_record.name, name_key: 'name')

    if track && track.dig('album', 'images').present?
      image_url = track.dig('album', 'images', 1, 'url') || track.dig('album', 'images', 0, 'url')
      @image_record.mark_found!(url: image_url, spotify_id: track['id'])
    else
      @image_record.mark_not_found!
    end
  end

  def search_spotify(type:, query:)
    response = HTTParty.get(
      'https://api.spotify.com/v1/search',
      headers: spotify_headers,
      query: {
        q: query,
        type: type,
        limit: 5
      }
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.warn("Spotify search failed: #{response.code} - #{response.body}")
      {}
    end
  end

  def find_best_match(items, target_name, name_key:)
    return nil if items.empty?

    target_normalized = normalize_name(target_name)

    # First try exact match
    exact = items.find { |item| normalize_name(item[name_key]) == target_normalized }
    return exact if exact

    # Then try fuzzy match (contains or contained by)
    fuzzy = items.find do |item|
      item_normalized = normalize_name(item[name_key])
      item_normalized.include?(target_normalized) || target_normalized.include?(item_normalized)
    end
    return fuzzy if fuzzy

    # Fall back to first result if reasonably close
    first = items.first
    first_normalized = normalize_name(first[name_key])

    # Accept first result if at least 50% of words match
    target_words = target_normalized.split
    first_words = first_normalized.split
    matching_words = (target_words & first_words).size
    total_words = [target_words.size, first_words.size].max

    if total_words > 0 && matching_words.to_f / total_words >= 0.5
      first
    else
      nil
    end
  end

  def normalize_name(name)
    return '' unless name

    name.downcase
        .gsub(/[^\w\s]/, '') # Remove punctuation
        .gsub(/\s+/, ' ')    # Normalize whitespace
        .strip
  end

  def ensure_authenticated!
    return if @access_token && @token_expires_at && @token_expires_at > Time.current

    authenticate!
  end

  def authenticate!
    response = HTTParty.post(
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
    else
      raise "Failed to authenticate with Spotify: #{response.body}"
    end
  end

  def spotify_headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end
end
