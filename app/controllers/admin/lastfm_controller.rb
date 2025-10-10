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
  
  def authenticate_admin!
    # Add your admin authentication logic here
    # For now, just use authenticate_user!
    authenticate_user!
  end
end
