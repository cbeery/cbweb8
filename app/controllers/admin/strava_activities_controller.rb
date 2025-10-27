# app/controllers/admin/strava_activities_controller.rb
class Admin::StravaActivitiesController < Admin::BaseController
  before_action :set_activity, only: [:show]
  
  def index
    @activities = StravaActivity.includes(:ride)
    
    # Activity type filter
    @activities = @activities.by_type(params[:activity_type]) if params[:activity_type].present?
    
    # Date filters
    if params[:start_date].present?
      @activities = @activities.where('started_at >= ?', params[:start_date])
    end
    
    if params[:end_date].present?
      @activities = @activities.where('started_at <= ?', params[:end_date])
    end
    
    # Other filters
    @activities = @activities.with_gear if params[:has_gear] == 'true'
    @activities = @activities.commutes if params[:commute] == 'true'
    @activities = @activities.non_commutes if params[:commute] == 'false'
    @activities = @activities.private_activities if params[:private] == 'true'
    @activities = @activities.public_activities if params[:private] == 'false'
    
    # Location filter
    if params[:city].present?
      @activities = @activities.where('city ILIKE ?', "%#{params[:city]}%")
    end
    
    # Search
    if params[:q].present?
      @activities = @activities.where('name ILIKE ?', "%#{params[:q]}%")
    end
    
    # Calculate stats before pagination
    @stats = {
      total_activities: @activities.count,
      total_distance: @activities.sum(:distance_in_miles),
      total_time: @activities.sum(:moving_time),
      activity_types: @activities.group(:activity_type).count
    }
    
    # Sorting
    @activities = case params[:sort]
    when 'date_asc'
      @activities.order(started_at: :asc)
    when 'distance'
      @activities.order(distance: :desc)
    when 'duration'
      @activities.order(moving_time: :desc)
    when 'type'
      @activities.order(:activity_type, started_at: :desc)
    else
      @activities.recent
    end
    
    @activities = @activities.page(params[:page]).per(50)
    
    # Get filter options
    @activity_types = StravaActivity.distinct.pluck(:activity_type).compact.sort
    @cities = StravaActivity.where.not(city: nil).distinct.pluck(:city).sort
  end
  
  def show
    @ride = @activity.ride
    @bicycle = @activity.find_bicycle
    
    # Find adjacent activities
    @previous_activity = StravaActivity.where('started_at < ?', @activity.started_at)
                                      .recent.first
    @next_activity = StravaActivity.where('started_at > ?', @activity.started_at)
                                   .order(started_at: :asc).first
  end
  
  # Sync all recent Strava activities
  def sync
    sync_status = SyncStatus.create!(
      source_type: 'strava',
      interactive: true,
      user: current_user,
      metadata: {
        days_back: params[:days_back] || 7,
        triggered_by: current_user.email
      }
    )
    
    StravaActivitySyncJob.perform_later(sync_status.id)
    
    redirect_to admin_sync_path(sync_status), 
                notice: 'Strava sync started successfully'
  end
  
  private
  
  def set_activity
    @activity = StravaActivity.find(params[:id])
  end
end
