# app/controllers/admin/theaters_controller.rb
class Admin::TheatersController < Admin::BaseController
  before_action :set_theater, only: [:show, :edit, :update, :destroy]
  
  def index
    @theaters = Theater.includes(:viewings)
                      .left_joins(:viewings)
                      .group('theaters.id')
                      .select('theaters.*, COUNT(viewings.id) as viewings_count')
                      .order(:name)
    
    if params[:search].present?
      @theaters = @theaters.where("name ILIKE ? OR city ILIKE ?", 
                                 "%#{params[:search]}%", 
                                 "%#{params[:search]}%")
    end
    
    @theaters = @theaters.page(params[:page]).per(25)
  end
  
  def show
    @recent_viewings = @theater.viewings
                               .includes(:movie)
                               .order(viewed_on: :desc)
                               .limit(10)
  end
  
  def new
    @theater = Theater.new
  end
  
  def create
    @theater = Theater.new(theater_params)
    
    if @theater.save
      respond_to do |format|
        format.html { redirect_to admin_theater_path(@theater), notice: 'Theater was successfully created.' }
        format.json { render json: { id: @theater.id, name: @theater.display_name }, status: :created }
        format.turbo_stream { render turbo_stream: turbo_stream.append('theater_select', 
                                                                       "<option value='#{@theater.id}' selected>#{@theater.display_name}</option>") }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @theater.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def edit
  end
  
  def update
    if @theater.update(theater_params)
      redirect_to admin_theater_path(@theater), notice: 'Theater was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @theater.viewings.empty?
      @theater.destroy
      redirect_to admin_theaters_path, notice: 'Theater was successfully deleted.'
    else
      redirect_to admin_theater_path(@theater), alert: 'Cannot delete theater with existing viewings.'
    end
  end
  
  # POST /admin/theaters/quick_create
  # For AJAX inline creation from viewing form
  def quick_create
    @theater = Theater.new(theater_params)
    
    if @theater.save
      render json: { 
        id: @theater.id, 
        display_name: @theater.display_name,
        name: @theater.name,
        city: @theater.city,
        state: @theater.state
      }, status: :created
    else
      render json: { errors: @theater.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_theater
    @theater = Theater.find(params[:id])
  end
  
  def theater_params
    params.require(:theater).permit(:name, :city, :state, :address, :url, :notes)
  end
end
