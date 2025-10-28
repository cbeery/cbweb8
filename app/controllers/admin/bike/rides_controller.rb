# app/controllers/admin/rides_controller.rb
class Admin::Bike::RidesController < Admin::BaseController
  before_action :set_ride, only: [:show]
  
  def index
    @rides = Ride.includes(:bicycle, :strava_activity)
    
    # Date range filtering
    if params[:start_date].present?
      @rides = @rides.where('rode_on >= ?', params[:start_date])
    end
    
    if params[:end_date].present?
      @rides = @rides.where('rode_on <= ?', params[:end_date])
    end
    
    # Other filters
    @rides = @rides.by_bike(params[:bicycle_id]) if params[:bicycle_id].present?
    @rides = @rides.by_year(params[:year]) if params[:year].present?
    @rides = @rides.by_month(params[:month], params[:year]) if params[:month].present?
    
    # Strava filter
    case params[:strava]
    when 'true'
      @rides = @rides.with_strava
    when 'false'
      @rides = @rides.without_strava
    end
    
    # Search notes
    if params[:q].present?
      @rides = @rides.where('notes ILIKE ?', "%#{params[:q]}%")
    end
    
    # Distance filter
    if params[:min_miles].present?
      @rides = @rides.where('miles >= ?', params[:min_miles].to_f)
    end
    
    if params[:max_miles].present?
      @rides = @rides.where('miles <= ?', params[:max_miles].to_f)
    end
    
    # Calculate stats before pagination
    @stats = {
      total_rides: @rides.count,
      total_miles: @rides.sum(:miles),
      total_duration: @rides.sum(:duration),
      average_miles: @rides.average(:miles)&.round(2),
      longest_ride: @rides.maximum(:miles),
      average_speed: calculate_average_speed(@rides)
    }
    
    # Sorting
    @rides = case params[:sort]
    when 'date_asc'
      @rides.order(rode_on: :asc)
    when 'miles_desc'
      @rides.longest_first
    when 'miles_asc'
      @rides.shortest_first
    when 'duration'
      @rides.order(duration: :desc)
    when 'speed'
      @rides.select('rides.*, (miles * 3600.0 / NULLIF(duration, 0)) as speed')
            .order('speed DESC NULLS LAST')
    else
      @rides.recent
    end
    
    @rides = @rides.page(params[:page]).per(50)
    
    # Get filter options
    @available_bicycles = Bicycle.order(:name).pluck(:name, :id)
    @available_years = Ride.distinct
                          .pluck(Arel.sql('EXTRACT(YEAR FROM rode_on)::integer'))
                          .compact.sort.reverse
  end
  
  def show
    @bicycle = @ride.bicycle
    @strava_activity = @ride.strava_activity
    
    # Find adjacent rides
    @previous_ride = @bicycle.rides.where('rode_on < ?', @ride.rode_on).recent.first
    @next_ride = @bicycle.rides.where('rode_on > ?', @ride.rode_on).oldest_first.first
    
    # Find milestones around this ride
    @milestones_before = @bicycle.milestones
                                 .where('occurred_on <= ?', @ride.rode_on)
                                 .recent
                                 .limit(2)
    @milestones_after = @bicycle.milestones
                                .where('occurred_on > ?', @ride.rode_on)
                                .oldest_first
                                .limit(2)
  end
  
  # Special mileage calculator view
  def calculator
    @bicycles = Bicycle.active.includes(:rides, :milestones)
    
    # Handle calculation requests
    if params[:calculate].present?
      perform_mileage_calculation
    end
  end
  
  private
  
  def set_ride
    @ride = Ride.find(params[:id])
  end
  
  def calculate_average_speed(rides)
    total_miles = rides.sum(:miles)
    total_duration = rides.sum(:duration)
    
    return 0 if total_duration.zero? || total_miles.zero?
    
    hours = total_duration / 3600.0
    (total_miles / hours).round(1)
  end
  
  def perform_mileage_calculation
    @calculation_type = params[:calculation_type]
    
    case @calculation_type
    when 'all_time'
      if params[:bicycle_id].present?
        bicycle = Bicycle.find(params[:bicycle_id])
        @result = {
          bicycle: bicycle.name,
          miles: bicycle.total_miles,
          rides: bicycle.ride_count,
          duration: bicycle.total_duration_formatted
        }
      else
        @result = {
          bicycle: 'All Bicycles',
          miles: Ride.sum(:miles),
          rides: Ride.count,
          duration: format_duration(Ride.sum(:duration))
        }
      end
      
    when 'date_range'
      start_date = Date.parse(params[:start_date]) rescue Date.current.beginning_of_year
      end_date = Date.parse(params[:end_date]) rescue Date.current
      
      rides = Ride.between(start_date, end_date)
      rides = rides.by_bike(params[:bicycle_id]) if params[:bicycle_id].present?
      
      @result = {
        period: "#{start_date.strftime('%B %d, %Y')} to #{end_date.strftime('%B %d, %Y')}",
        miles: rides.sum(:miles),
        rides: rides.count,
        duration: format_duration(rides.sum(:duration))
      }
      
    when 'since_milestone'
      milestone = Milestone.find(params[:milestone_id])
      miles = milestone.miles_since
      rides = milestone.bicycle.rides.since(milestone.occurred_on)
      
      @result = {
        milestone: milestone.title,
        occurred_on: milestone.occurred_on,
        days_since: milestone.days_since,
        miles: miles,
        rides: rides.count,
        duration: format_duration(rides.sum(:duration))
      }
      
    when 'between_milestones'
      start_milestone = Milestone.find(params[:start_milestone_id])
      end_milestone = Milestone.find(params[:end_milestone_id])
      
      if start_milestone.bicycle_id != end_milestone.bicycle_id
        @error = "Milestones must be for the same bicycle"
      else
        miles = start_milestone.miles_until(end_milestone)
        rides = start_milestone.bicycle.rides
                              .between(start_milestone.occurred_on, end_milestone.occurred_on)
        
        @result = {
          start_milestone: start_milestone.title,
          end_milestone: end_milestone.title,
          miles: miles,
          rides: rides.count,
          duration: format_duration(rides.sum(:duration))
        }
      end
    end
  end
  
  def format_duration(seconds)
    return "0:00" if seconds.nil? || seconds.zero?
    
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    
    if hours > 0
      format("%d:%02d", hours, minutes)
    else
      format("%d:%02d", minutes / 60, minutes % 60)
    end
  end
end
