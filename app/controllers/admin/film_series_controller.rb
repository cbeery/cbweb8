# app/controllers/admin/film_series_controller.rb
class Admin::FilmSeriesController < Admin::BaseController
  before_action :set_film_series, only: [:show, :edit, :update, :destroy]
  
  def index
    @film_series = FilmSeries.includes(:film_series_events)
                            .order(:name)
                            .page(params[:page]).per(25)
  end
  
  def show
    @events = @film_series.film_series_events.includes(:viewings).order(started_on: :desc)
  end
  
  def new
    @film_series = FilmSeries.new
  end
  
  def create
    @film_series = FilmSeries.new(film_series_params)
    
    if @film_series.save
      respond_to do |format|
        format.html { redirect_to admin_film_series_path(@film_series), notice: 'Film series was successfully created.' }
        format.json { render json: { id: @film_series.id, name: @film_series.name }, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @film_series.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end
  
  def edit
  end
  
  def update
    if @film_series.update(film_series_params)
      redirect_to admin_film_series_path(@film_series), notice: 'Film series was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @film_series.film_series_events.empty?
      @film_series.destroy
      redirect_to admin_film_series_index_path, notice: 'Film series was successfully deleted.'
    else
      redirect_to admin_film_series_path(@film_series), alert: 'Cannot delete film series with existing events.'
    end
  end
  
  # POST /admin/film_series/quick_create
  # For AJAX inline creation from viewing form
  def quick_create
    @film_series = FilmSeries.new(film_series_params)
    
    if @film_series.save
      render json: { 
        id: @film_series.id, 
        name: @film_series.name,
        display_name: @film_series.display_name
      }, status: :created
    else
      render json: { errors: @film_series.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_film_series
    @film_series = FilmSeries.find(params[:id])
  end
  
  def film_series_params
    params.require(:film_series).permit(:name, :city, :state, :url, :description)
  end
end
