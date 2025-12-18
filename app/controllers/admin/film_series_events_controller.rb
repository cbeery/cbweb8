# app/controllers/admin/film_series_events_controller.rb
class Admin::FilmSeriesEventsController < Admin::BaseController
  before_action :set_film_series, except: [:for_series, :quick_create]
  before_action :set_event, only: [:show, :edit, :update, :destroy]
  
  def index
    @events = @film_series.film_series_events.order(started_on: :desc)
  end
  
  def show
    @viewings = @event.viewings.includes(:movie).order(viewed_on: :desc)
  end
  
  def new
    @event = @film_series.film_series_events.build
  end
  
  def create
    @event = @film_series.film_series_events.build(event_params)
    
    if @event.save
      redirect_to admin_film_series_film_series_event_path(@film_series, @event), 
                  notice: 'Event was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @event.update(event_params)
      redirect_to admin_film_series_film_series_event_path(@film_series, @event), 
                  notice: 'Event was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @event.viewings.empty?
      @event.destroy
      redirect_to admin_film_series_path(@film_series), notice: 'Event was successfully deleted.'
    else
      redirect_to admin_film_series_film_series_event_path(@film_series, @event), 
                  alert: 'Cannot delete event with existing viewings.'
    end
  end
  
  # GET /admin/film_series_events/for_series
  # AJAX endpoint to get events for a specific series
  def for_series
    series_id = params[:series_id]

    if series_id.present?
      events = FilmSeriesEvent.where(film_series_id: series_id)
                             .order(started_on: :desc)
                             .map { |e| { id: e.id, name: e.name, started_on: e.started_on } }

      render json: events
    else
      render json: []
    end
  end
  
  # POST /admin/film_series_events/quick_create
  # For AJAX inline creation from viewing form
  def quick_create
    @event = FilmSeriesEvent.new(event_params)
    
    if @event.save
      render json: { 
        id: @event.id, 
        name: @event.display_name,
        film_series_id: @event.film_series_id
      }, status: :created
    else
      render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_film_series
    @film_series = FilmSeries.find(params[:film_series_id])
  end
  
  def set_event
    @event = @film_series.film_series_events.find(params[:id])
  end
  
  def event_params
    params.require(:film_series_event).permit(:name, :film_series_id, :started_on, :ended_on, :notes, :url)
  end
end
