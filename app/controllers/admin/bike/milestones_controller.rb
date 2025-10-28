# app/controllers/admin/milestones_controller.rb
class Admin::Bike::MilestonesController < Admin::BaseController
  before_action :set_milestone, only: [:show, :edit, :update, :destroy]
  before_action :load_bicycles, only: [:new, :edit, :create, :update]
  
  def index
    @milestones = Milestone.includes(:bicycle)
    
    # Filtering
    @milestones = @milestones.by_bike(params[:bicycle_id]) if params[:bicycle_id].present?
    @milestones = @milestones.by_year(params[:year]) if params[:year].present?
    
    # Filter by maintenance type
    if params[:maintenance] == 'true'
      @milestones = @milestones.select(&:maintenance?)
    elsif params[:maintenance] == 'false'
      @milestones = @milestones.reject(&:maintenance?)
    end
    
    # Search
    if params[:q].present?
      @milestones = @milestones.where('title ILIKE ? OR description ILIKE ?', 
                                       "%#{params[:q]}%", "%#{params[:q]}%")
    end
    
    # Sorting
    @milestones = case params[:sort]
    when 'date_asc'
      @milestones.oldest_first
    when 'bicycle'
      @milestones.joins(:bicycle).order('bicycles.name, milestones.occurred_on DESC')
    else
      @milestones.recent
    end
    
    # Get filter options
    @available_bicycles = Bicycle.order(:name).pluck(:name, :id)
    @available_years = Milestone.distinct
                                .pluck(Arel.sql('EXTRACT(YEAR FROM occurred_on)::integer'))
                                .compact.sort.reverse
  end
  
  def show
    @activity_summary = @milestone.activity_summary
    @next_milestone = @milestone.next_milestone
    @previous_milestone = @milestone.previous_milestone
    
    # Get rides since this milestone
    @rides_since = @milestone.bicycle.rides
                             .since(@milestone.occurred_on)
                             .recent
                             .limit(10)
  end
  
  def new
    @milestone = Milestone.new(
      bicycle_id: params[:bicycle_id],
      occurred_on: Date.current
    )
  end
  
  def create
    @milestone = Milestone.new(milestone_params)
    
    if @milestone.save
      redirect_to admin_milestone_path(@milestone), 
                  notice: 'Milestone was successfully created.'
    else
      load_bicycles
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @milestone.update(milestone_params)
      redirect_to admin_milestone_path(@milestone), 
                  notice: 'Milestone was successfully updated.'
    else
      load_bicycles
      render :edit
    end
  end
  
  def destroy
    bicycle = @milestone.bicycle
    @milestone.destroy
    redirect_to admin_bike_milestones_path(bicycle_id: bicycle.id), 
                notice: 'Milestone was successfully deleted.'
  end
  
  private
  
  def set_milestone
    @milestone = Milestone.find(params[:id])
  end
  
  def load_bicycles
    @bicycles = Bicycle.active.order(:name).pluck(:name, :id)
  end
  
  def milestone_params
    params.require(:milestone).permit(:bicycle_id, :occurred_on, :title, :description)
  end
end
