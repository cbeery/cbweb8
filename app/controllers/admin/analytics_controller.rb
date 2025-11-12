# app/controllers/admin/analytics_controller.rb
class Admin::AnalyticsController < Admin::BaseController
  def index
    # Movies Analytics - through viewings table
    @movies_by_year = Viewing.group_by_year(:viewed_on).count
    @movies_by_month_current_year = Viewing
      .where(viewed_on: Date.current.beginning_of_year..)
      .group_by_month(:viewed_on, format: "%b")
      .count
    @top_movie_years = Movie.group(:year).count.sort_by { |_, v| -v }.first(10)
    
    # Concerts Analytics  
    @concerts_by_year = Concert.group_by_year(:played_on).count
    @concerts_by_venue = Concert.includes(:concert_venue)
      .group('concert_venues.name')
      .references(:concert_venues)
      .count
      .sort_by { |_, v| -v }
      .first(10)
    
    # Concert Artists Analytics
    @top_artists = ConcertArtist.joins(:concerts)
      .group('concert_artists.id')
      .order('COUNT(concerts.id) DESC')
      .limit(20)
      .pluck('concert_artists.name', 'COUNT(concerts.id)')
    
    # Books Analytics
    @books_by_status = Book.group(:status).count
    @books_by_year_read = Book.left_joins(:book_reads)
      .where.not('book_reads.finished_on' =>  nil)
      .group_by_year('book_reads.finished_on')
      .count

    # Bike Analytics
    @rides_by_month = Ride
      .where(rode_on: 1.year.ago..)
      .group_by_month(:rode_on, format: "%b %Y")
      .count
    @miles_by_month = Ride
      .where(rode_on: 1.year.ago..)
      .group_by_month(:rode_on, format: "%b %Y")
      .sum(:miles)
    @rides_by_bike = Bicycle.joins(:rides)
      .group('bicycles.name')
      .sum('rides.miles')
      .sort_by { |_, v| -v }
    
    # NBA Analytics
    @nba_games_by_season = NbaGame.group(:season).count
    @nba_games_watched = NbaGame.watched.group(:season).count
    @nba_quarters_by_season = NbaGame
      .group(:season)
      .sum(:quarters_watched)
    
    # Last.fm Analytics
    @scrobbles_by_month = ScrobbleCount
      .where(played_on: 1.year.ago..)
      .group_by_month(:played_on, format: "%b %Y")
      .sum(:plays)
    @top_scrobbled_artists = ScrobblePlay
      .joins(:scrobble_artist)
      .where(category: 'artist')
      .group('scrobble_artists.name')
      .sum(:plays)
      .sort_by { |_, v| -v }
      .first(15)
    
    # Spotify Analytics
    @playlists_by_year = SpotifyPlaylist.group(:year).count
    @mixtapes_by_maker = SpotifyPlaylist
      .mixtapes
      .group(:made_by)
      .count
    @spotify_tracks_by_year = SpotifyTrack
      .joins(:spotify_playlists)
      .where(spotify_playlists: { mixtape: true })
      .group('spotify_playlists.year')
      .count('DISTINCT spotify_tracks.id')
    
    # Sync Analytics
    @syncs_by_source = SyncStatus.group(:source_type).count
    @sync_success_rate = calculate_sync_success_rate
    @syncs_by_day = SyncStatus
      .where(created_at: 30.days.ago..)
      .group_by_day(:created_at)
      .count
    
    # Activity Heatmap Data (for calendar view)
    @activity_data = prepare_activity_heatmap_data
  end
  
  private
  
  def calculate_sync_success_rate
    total = SyncStatus.count
    return {} if total == 0
    
    SyncStatus.group(:status).count.transform_values do |count|
      (count.to_f / total * 100).round(1)
    end
  end
  
  def prepare_activity_heatmap_data
    # Combine different activities into a daily count
    end_date = Date.current
    start_date = end_date - 365.days
    
    data = {}
    
    # Add viewings (movie watches)
    Viewing.where(viewed_on: start_date..end_date)
      .group(:viewed_on)
      .count
      .each { |date, count| data[date] ||= 0; data[date] += count }
    
    # Add concerts  
    Concert.where(played_on: start_date..end_date)
      .group(:played_on)
      .count
      .each { |date, count| data[date] ||= 0; data[date] += count }
    
    # Add rides
    Ride.where(rode_on: start_date..end_date)
      .group(:rode_on)
      .count
      .each { |date, count| data[date] ||= 0; data[date] += count }
    
    # Add NBA games watched
    NbaGame.watched
      .where(played_on: start_date..end_date)
      .group(:played_on)
      .count
      .each { |date, count| data[date] ||= 0; data[date] += count }
    
    # Format for JavaScript consumption
    data.map { |date, count| { date: date.to_s, count: count } }
  end
end
