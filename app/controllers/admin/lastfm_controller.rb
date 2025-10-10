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
  
  def sync
    # Trigger the sync service
    job_id = Sync::TopScrobblesService.new.sync
    
    redirect_to admin_lastfm_top_path, 
                notice: "Last.fm sync started. Job ID: #{job_id}"
  rescue => e
    redirect_to admin_lastfm_top_path, 
                alert: "Sync failed: #{e.message}"
  end
  
  private
  
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
