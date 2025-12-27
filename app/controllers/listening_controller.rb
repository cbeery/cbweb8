# app/controllers/listening_controller.rb
class ListeningController < ApplicationController
  def index
    # Top Artists by period
    @top_artists_week = top_scrobbles('artist', '7day', 10)
    @top_artists_month = top_scrobbles('artist', '1month', 10)
    @top_artists_year = top_scrobbles('artist', '12month', 10)
    @top_artists_overall = top_scrobbles('artist', 'overall', 10)

    # Top Albums by period
    @top_albums_month = top_scrobbles('album', '1month', 10)
    @top_albums_year = top_scrobbles('album', '12month', 10)

    # Top Tracks by period
    @top_tracks_month = top_scrobbles('track', '1month', 10)
    @top_tracks_year = top_scrobbles('track', '12month', 10)

    # Preload images for all scrobbles
    load_images
  end

  private

  def top_scrobbles(category, period, limit = 10)
    TopScrobble.where(category: category, period: period)
               .order(rank: :asc)
               .limit(limit)
  end

  def load_images
    # Collect all unique artist names for artist images
    all_artists = [
      @top_artists_week,
      @top_artists_month,
      @top_artists_year,
      @top_artists_overall
    ].flatten.compact.map(&:artist).uniq

    @artist_images = TopScrobbleImage.where(category: 'artist', artist: all_artists, name: nil)
                                      .index_by(&:artist)

    # Collect all album entries for album images
    album_keys = [
      @top_albums_month,
      @top_albums_year
    ].flatten.compact.map { |s| [s.artist, s.name] }

    @album_images = TopScrobbleImage.where(category: 'album')
                                     .where(artist: album_keys.map(&:first).uniq)
                                     .index_by { |img| [img.artist, img.name] }

    # Collect all track entries for track images (uses album image)
    track_keys = [
      @top_tracks_month,
      @top_tracks_year
    ].flatten.compact.map { |s| [s.artist, s.name] }

    @track_images = TopScrobbleImage.where(category: 'track')
                                     .where(artist: track_keys.map(&:first).uniq)
                                     .index_by { |img| [img.artist, img.name] }
  end
end
