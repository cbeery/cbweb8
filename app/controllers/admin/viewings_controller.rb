# app/controllers/admin/viewings_controller.rb
class Admin::ViewingsController < Admin::BaseController
  before_action :set_movie
  before_action :set_viewing, only: [:edit, :update, :destroy]
  
  def new
    @viewing = @movie.viewings.new
  end
  
  def create
    @viewing = @movie.viewings.new(viewing_params)
    
    if @viewing.save
      redirect_to admin_movie_path(@movie), notice: 'Viewing was successfully added.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @viewing.update(viewing_params)
      redirect_to admin_movie_path(@movie), notice: 'Viewing was successfully updated.'
    else
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
