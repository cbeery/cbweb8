# app/controllers/admin/bicycles_controller.rb
class Admin::BicyclesController < Admin::BaseController
  before_action :set_bicycle, only: [:show, :edit, :update, :destroy, :sync]
  
  def index
    @bicycles = Bicycle.includes(:rides, :milestones)
    
    # Filtering
    @bicycles = @bicycles.active if params[:active] == 'true'
    @bicycles = @bicycles.inactive if params[:active] == 'false'
    @bicycles = @bicycles.with_strava if params[:strava] == 'true'
    
    # Search
    if params[:q].present?
      @bicycles = @bicycles.where('name ILIKE ? OR notes ILIKE ?', 
                                   "%#{params[:q]}%", "%#{params[:q]}%")
    end
    
    # Sorting
    @bicycles = case params[:sort]
    when 'name'
      @bicycles.order(:name)
    when 'miles'
      @bicycles.left_joins(:rides)
               .group('bicycles.id')
               .order('SUM(rides.miles) DESC NULLS LAST')
    when 'rides'
      @bicycles.left_joins(:rides)
               .group('bicycles.id')
               .order('COUNT(rides.id) DESC')
    when 'recent'
      @bicycles.by_most_recent_ride
    else
      @bicycles.alphabetical
    end
    
    # Calculate aggregates for each bike
    @bike_stats = {}
    @bicycles.each do |bike|
      @bike_stats[bike.id] = {
        total_miles: bike.total_miles,
        ride_count: bike.ride_count,
        recent_ride: bike.rides.recent.first,
        milestone_count: bike.milestone_count
      }
    end
    
    # Overall stats
    @total_miles = Ride.sum(:miles)
    @total_rides = Ride.count
    @active_bikes = Bicycle.active.count
  end
  
  def show
    @recent_rides = @bicycle.rides.recent.limit(10).includes(:strava_activity)
    @recent_milestones = @bicycle.milestones.recent.limit(5)
    
    # Calculate stats
    @stats = {
      total_miles: @bicycle.total_miles,
      total_duration: @bicycle.total_duration,
      average_speed: @bicycle.average_speed,
      ride_count: @bicycle.ride_count,
      this_year_miles: @bicycle.miles_between(Date.current.beginning_of_year, Date.current),
      this_month_miles: @bicycle.miles_between(Date.current.beginning_of_month, Date.current),
      last_30_days_miles: @bicycle.miles_between(30.days.ago, Date.current)
    }
    
    # Maintenance milestones with mileage
    @maintenance_milestones = @bicycle.milestones.select(&:maintenance?).map do |milestone|
      {
        milestone: milestone,
        miles_since: milestone.miles_since,
        days_since: milestone.days_since
      }
    end
  end
  
  def new
    @bicycle = Bicycle.new(active: true)
  end
  
  def create
    @bicycle = Bicycle.new(bicycle_params)
    
    if @bicycle.save
      redirect_to admin_bicycle_path(@bicycle), 
                  notice: 'Bicycle was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @bicycle.update(bicycle_params)
      redirect_to admin_bicycle_path(@bicycle), 
                  notice: 'Bicycle was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @bicycle.destroy
    redirect_to admin_bicycles_path, 
                notice: 'Bicycle was successfully deleted.'
  end
  
  private
  
  def set_bicycle
    @bicycle = Bicycle.find(params[:id])
  end
  
  def bicycle_params
    params.require(:bicycle).permit(:name, :notes, :active, :strava_gear_id)
  end
end
