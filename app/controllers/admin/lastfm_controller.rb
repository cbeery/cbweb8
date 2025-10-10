class Admin::LastfmController < Admin::BaseController
  CATEGORIES = %w[artist album track].freeze
  PERIODS = %w[7day 1month 3month 6month 12month overall].freeze
  
  PERIOD_LABELS = {
    '7day' => 'Last 7 days',
    '1month' => 'Last month',
    '3month' => 'Last 3 months',
    '6month' => 'Last 6 months',
    '12month' => 'Last year',
    'overall' => 'All-time'
  }.freeze
  
  def top
    @category = params[:category] || 'artist'
    @period = params[:period] || '7day'
    
    # Validate params
    @category = 'artist' unless CATEGORIES.include?(@category)
    @period = '7day' unless PERIODS.include?(@period)
    
    @top_scrobbles = TopScrobble.where(category: @category, period: @period)
                                .order(:position)
                                .limit(50)
    
    # Get last sync time
    @last_sync = TopScrobble.where(category: @category, period: @period)
                            .maximum(:revised_at)
    
    # If this is a Turbo Frame request, just render the table partial
    if turbo_frame_request?
      render partial: 'top_table'
    else
      render :top
    end
  end
  
  def counts
    @page = (params[:page] || 1).to_i
    @per_page = 30
    
    # Get date range for filtering
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 3.months.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
    
    # Get daily counts with pagination
    @scrobble_counts = ScrobbleCount
                        .where(played_on: @start_date..@end_date)
                        .order(played_on: :desc)
                        .limit(@per_page)
                        .offset((@page - 1) * @per_page)
    
    # Get total count for pagination
    @total_count = ScrobbleCount.where(played_on: @start_date..@end_date).count
    @total_pages = (@total_count.to_f / @per_page).ceil
    
    # Calculate summaries
    calculate_summaries
    
    # Get recent stats
    calculate_recent_stats
  end
  
  def plays
    @week = params[:week].present? ? Date.parse(params[:week]) : Date.today.beginning_of_week
    @search = params[:search]
    @category = params[:category] || 'artist'
    
    # Validate category
    @category = 'artist' unless %w[artist album].include?(@category)
    
    if @search.present?
      # Search mode - show history for a specific artist/album
      search_plays_history
    else
      # Week view mode - show top artists/albums for selected week
      load_weekly_plays
    end
    
    # Get available weeks for navigation
    @available_weeks = ScrobblePlay.select(:played_on)
                                   .distinct
                                   .order(played_on: :desc)
                                   .limit(52)
                                   .pluck(:played_on)
    
    # Calculate weekly stats
    calculate_weekly_stats
  end
  
  private
  
  def search_plays_history
    if @category == 'artist'
      artist = ScrobbleArtist.where('name ILIKE ?', "%#{@search}%").first
      if artist
        @plays = ScrobblePlay.where(scrobble_artist: artist, category: 'artist')
                             .order(played_on: :desc)
                             .includes(:scrobble_artist)
                             .limit(52)
        
        # Also get album plays for this artist
        @album_plays = ScrobblePlay.where(scrobble_artist: artist, category: 'album')
                                   .order(played_on: :desc)
                                   .includes(:scrobble_album)
                                   .limit(52)
      else
        @plays = ScrobblePlay.none
        @album_plays = ScrobblePlay.none
      end
    else
      # Search for albums
      @plays = ScrobblePlay.joins(:scrobble_album)
                           .where('scrobble_albums.name ILIKE ?', "%#{@search}%")
                           .where(category: 'album')
                           .order(played_on: :desc)
                           .includes(:scrobble_album, :scrobble_artist)
                           .limit(52)
    end
  end
  
  def load_weekly_plays
    # Get top artists/albums for the selected week
    @plays = ScrobblePlay.where(played_on: @week, category: @category)
                         .order(plays: :desc)
                         .includes(:scrobble_artist, :scrobble_album)
                         .limit(50)
    
    # Get week-over-week comparison
    previous_week = @week - 1.week
    @previous_week_plays = ScrobblePlay.where(played_on: previous_week, category: @category)
                                       .includes(:scrobble_artist, :scrobble_album)
                                       .index_by do |play|
                                         if @category == 'artist'
                                           play.scrobble_artist_id
                                         else
                                           play.scrobble_album_id
                                         end
                                       end
  end
  
  def calculate_weekly_stats
    week_plays = ScrobblePlay.where(played_on: @week)
    
    @weekly_stats = {
      total_artists: week_plays.where(category: 'artist').count,
      total_albums: week_plays.where(category: 'album').count,
      total_artist_plays: week_plays.where(category: 'artist').sum(:plays),
      total_album_plays: week_plays.where(category: 'album').sum(:plays),
      top_artist: week_plays.where(category: 'artist')
                            .order(plays: :desc)
                            .first,
      top_album: week_plays.where(category: 'album')
                           .order(plays: :desc)
                           .includes(:scrobble_artist)
                           .first
    }
    
    # Get historical trends (last 8 weeks)
    @trend_weeks = (0..7).map { |i| @week - i.weeks }.reverse
    @trends = {
      artists: @trend_weeks.map do |week|
        ScrobblePlay.where(played_on: week, category: 'artist').count
      end,
      plays: @trend_weeks.map do |week|
        ScrobblePlay.where(played_on: week, category: 'artist').sum(:plays)
      end
    }
  end
  
  def calculate_summaries
    all_counts = ScrobbleCount.where(played_on: @start_date..@end_date)
    
    @summaries = {
      daily_avg: calculate_daily_average(all_counts),
      weekly: calculate_weekly_summary(all_counts),
      monthly: calculate_monthly_summary(all_counts),
      yearly: calculate_yearly_summary(all_counts)
    }
  end
  
  def calculate_daily_average(counts)
    return 0 if counts.empty?
    
    total_plays = counts.sum(:plays)
    days = counts.count
    (total_plays.to_f / days).round(1)
  end
  
  def calculate_weekly_summary(counts)
    counts.group_by { |c| c.played_on.beginning_of_week }
          .transform_values { |week_counts| week_counts.sum(&:plays) }
          .sort_by { |week, _| week }
          .reverse
          .first(12) # Last 12 weeks
  end
  
  def calculate_monthly_summary(counts)
    counts.group_by { |c| c.played_on.beginning_of_month }
          .transform_values { |month_counts| month_counts.sum(&:plays) }
          .sort_by { |month, _| month }
          .reverse
          .first(12) # Last 12 months
  end
  
  def calculate_yearly_summary(counts)
    counts.group_by { |c| c.played_on.year }
          .transform_values { |year_counts| year_counts.sum(&:plays) }
          .sort_by { |year, _| year }
          .reverse
  end
  
  def calculate_recent_stats
    @recent_stats = {
      today: ScrobbleCount.find_by(played_on: Date.today)&.plays || 0,
      yesterday: ScrobbleCount.find_by(played_on: Date.yesterday)&.plays || 0,
      this_week: ScrobbleCount.where(played_on: Date.current.beginning_of_week..Date.today).sum(:plays),
      last_week: ScrobbleCount.where(played_on: 1.week.ago.beginning_of_week..1.week.ago.end_of_week).sum(:plays),
      this_month: ScrobbleCount.where(played_on: Date.current.beginning_of_month..Date.today).sum(:plays),
      last_month: ScrobbleCount.where(played_on: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).sum(:plays)
    }
    
    # Calculate high/low
    all_time = ScrobbleCount.all
    @recent_stats[:highest_day] = all_time.maximum(:plays) || 0
    @recent_stats[:lowest_day] = all_time.where('plays > 0').minimum(:plays) || 0
    @recent_stats[:highest_date] = all_time.order(plays: :desc).first&.played_on
    @recent_stats[:lowest_date] = all_time.where('plays > 0').order(:plays).first&.played_on
  end
  
  def authenticate_admin!
    # Add your admin authentication logic here
    # For now, just use authenticate_user!
    authenticate_user!
  end
end
