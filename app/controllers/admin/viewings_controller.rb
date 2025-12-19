# app/controllers/admin/viewings_controller.rb
class Admin::ViewingsController < Admin::BaseController
  before_action :set_movie
  before_action :set_viewing, only: [:edit, :update, :destroy]
  
  def new
    @viewing = @movie.viewings.new
    load_form_data
  end
  
  def create
    @viewing = @movie.viewings.new(viewing_params)
    
    if @viewing.save
      redirect_to admin_movie_path(@movie), notice: 'Viewing was successfully added.'
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    load_form_data
  end
  
  def update
    if @viewing.update(viewing_params)
      redirect_to admin_movie_path(@movie), notice: 'Viewing was successfully updated.'
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @viewing.destroy
    redirect_to admin_movie_path(@movie), notice: 'Viewing was successfully deleted.'
  end
  
  private
  
  def set_movie
    @movie = Movie.find(params[:movie_id])
  end
  
  def set_viewing
    @viewing = @movie.viewings.find(params[:id])
  end
  
  def load_form_data
    @theaters = Theater.alphabetical
    @film_series = FilmSeries.alphabetical
    
    # Load events for the selected series if present
    if @viewing&.film_series_event_id.present?
      series_id = @viewing.film_series_event.film_series_id
      @film_series_events = FilmSeriesEvent.where(film_series_id: series_id).recent
    else
      @film_series_events = []
    end
  end
  
  def viewing_params
    params.require(:viewing).permit(
      :viewed_on, 
      :notes, 
      :rewatch, 
      :location,
      :theater_id,
      :film_series_event_id,
      :price,
      :format,
      :time
    )
  end
end
