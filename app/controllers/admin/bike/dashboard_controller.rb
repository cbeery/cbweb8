# app/controllers/admin/bike/dashboard_controller.rb
class Admin::Bike::DashboardController < Admin::BaseController
  def index
    # Summary stats for the Bike dashboard
    @total_bicycles = Bicycle.count
    @active_bicycles = Bicycle.active.count
    @total_rides = Ride.count
    @total_distance = Ride.sum(:distance_miles) || 0
    @total_duration = Ride.sum(:duration_seconds) || 0
    @current_year = Date.current.year
    
    # Recent rides
    @recent_rides = Ride.includes(:bicycle)
                        .order(ride_date: :desc)
                        .limit(10)
    
    # This year's stats
    @year_rides = Ride.by_year(@current_year).count
    @year_distance = Ride.by_year(@current_year).sum(:distance_miles) || 0
    @year_duration = Ride.by_year(@current_year).sum(:duration_seconds) || 0
    
    # This month's stats
    @month_rides = Ride.by_month(Date.current).count
    @month_distance = Ride.by_month(Date.current).sum(:distance_miles) || 0
    
    # Bike usage stats
    @bike_stats = Bicycle.active
                         .joins(:rides)
                         .select('bicycles.*, 
                                 COUNT(rides.id) as ride_count,
                                 SUM(rides.distance_miles) as total_miles,
                                 MAX(rides.ride_date) as last_ride_date')
                         .group('bicycles.id')
                         .order('total_miles DESC')
    
    # Upcoming milestones
    @upcoming_milestones = Milestone.pending
                                    .order(:target_date)
                                    .limit(5)
    
    # Recent Strava sync status
    @last_strava_sync = SyncStatus.where(source_type: 'strava')
                                  .order(created_at: :desc)
                                  .first
  end
end