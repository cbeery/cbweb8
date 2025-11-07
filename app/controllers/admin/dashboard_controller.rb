# app/controllers/admin/dashboard_controller.rb
class Admin::DashboardController < Admin::BaseController
  def index
    # Recent sync activities
    @recent_syncs = SyncStatus
      .includes(:user)
      .order(created_at: :desc)
      .limit(5)
    
    # Recent log entries
    @recent_logs = LogEntry
      .includes(:loggable, :user)
      .recent
      .limit(10)
    
    # Core content stats (removed Users)
    @total_movies = Movie.count
    @total_concerts = Concert.count
    @total_books = Book.count
    @total_rides = Ride.count
    @total_artists = ConcertArtist.count  # Fixed: using ConcertArtist instead of Artist
    
    # Last.fm stats
    @total_scrobbles = ScrobbleCount.sum(:plays)
    @scrobble_days = ScrobbleCount.count
    @last_scrobble_date = ScrobbleCount.maximum(:played_on)
    @scrobble_artists = ScrobbleArtist.count
    @scrobble_albums = ScrobbleAlbum.count
    
    # Spotify stats
    @total_playlists = SpotifyPlaylist.count
    @total_mixtapes = SpotifyPlaylist.mixtapes.count
    @spotify_tracks = SpotifyTrack.count
    @last_spotify_sync = SpotifyPlaylist.maximum(:last_synced_at)
    
    # NBA stats
    @total_nba_games = NbaGame.count
    @games_watched = NbaGame.watched.count
    @current_season_games = NbaGame.by_season(NbaGame.current_season).count rescue 0
    @nba_teams = NbaTeam.active.count
    
    # Today's activity
    @todays_syncs = SyncStatus.where(created_at: Time.current.beginning_of_day..).count
    @todays_logs = LogEntry.today.count
    @active_jobs = SolidQueue::Job.where(finished_at: nil).count rescue 0
  end
end
