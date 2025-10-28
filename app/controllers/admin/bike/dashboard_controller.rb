# app/controllers/admin/bike/dashboard_controller.rb
class Admin::Bike::DashboardController < Admin::BaseController
  def index
    # Summary stats for the Bike dashboard
    @total_bicycles = Bicycle.count
    @active_bicycles = Bicycle.active.count
    @total_rides = Ride.count
    @total_distance = Ride.sum(:miles) || 0
    @total_duration = Ride.sum(:duration) || 0
    @current_year = Date.current.year
    @current_month = Date.current.month
    
    # Recent rides
    @recent_rides = Ride.includes(:bicycle)
                        .order(rode_on: :desc)
                        .limit(10)
    
    # This year's stats
    @year_rides = Ride.by_year(@current_year).count
    @year_distance = Ride.by_year(@current_year).sum(:miles) || 0
    @year_duration = Ride.by_year(@current_year).sum(:duration) || 0
    
    # This month's stats
    @month_rides = Ride.by_month(@current_month, @current_year).count
    @month_distance = Ride.by_month(@current_month, @current_year).sum(:miles) || 0
    
    # Bike usage stats
    @bike_stats = Bicycle.active
                         .joins(:rides)
                         .select('bicycles.*, 
                                 COUNT(rides.id) as ride_count,
                                 SUM(rides.miles) as total_miles,
                                 MAX(rides.rode_on) as last_ride_date')
                         .group('bicycles.id')
                         .order('total_miles DESC')
    
    # Upcoming milestones
    @upcoming_milestones = Milestone.order(:occurred_on)
                                    .limit(5)
    
    # Recent Strava sync status
    @last_strava_sync = SyncStatus.where(source_type: 'strava')
                                  .order(created_at: :desc)
                                  .first
  end
end