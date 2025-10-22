class Admin::ConcertsController < Admin::BaseController
  before_action :set_concert, only: [:show, :edit, :update, :destroy]
  before_action :load_filter_context, only: [:index]
  
  def index
    @concerts = Concert.includes(:concert_venue, :concert_artists)
    
    # Apply filters
    if params[:artist_id].present?
      @concerts = @concerts.joins(:concert_performances)
                          .where(concert_performances: { concert_artist_id: params[:artist_id] })
    end
    
    if params[:venue_id].present?
      @concerts = @concerts.where(concert_venue_id: params[:venue_id])
    end
    
    @concerts = @concerts.recent
                         .page(params[:page])
                         .per(25)
  end
  
  def show
  end
  
  def new
    @concert = Concert.new
    @concert.concert_performances.build
  end
  
  def create
    @concert = Concert.new(concert_params_with_new_records)
    
    if @concert.save
      redirect_to admin_concert_path(@concert), notice: 'Concert was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @concert.concert_performances.build if @concert.concert_performances.empty?
  end
  
  def update
    if @concert.update(concert_params_with_new_records)
      redirect_to admin_concert_path(@concert), notice: 'Concert was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @concert.destroy!
    redirect_to admin_concerts_path, notice: 'Concert was successfully deleted.'
  end

  def search_artists
    @artists = ConcertArtist.where("name ILIKE ?", "%#{params[:q]}%")
                            .limit(10)
                            .order(:name)
    
    render json: @artists.map { |a| { id: a.id, name: a.name } }
  end
  
  def search_venues
    @venues = ConcertVenue.where("name ILIKE ? OR city ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
                          .limit(10)
                          .order(:name)
    
    render json: @venues.map { |v| { 
      id: v.id, 
      name: v.name,
      display_name: v.display_name 
    }}
  end

  
  private
  
  def load_filter_context
    @filtered_artist = ConcertArtist.find(params[:artist_id]) if params[:artist_id]
    @filtered_venue = ConcertVenue.find(params[:venue_id]) if params[:venue_id]
  end
  
  def set_concert
    @concert = Concert.find(params[:id])
  end
  
  def concert_params
    params.require(:concert).permit(
      :played_on, 
      :notes,
      :concert_venue_id,
      concert_performances_attributes: [:id, :concert_artist_id, :position, :_destroy]
    )
  end
  
  def concert_params_with_new_records
    modified_params = concert_params.to_h.deep_dup
    
    # Handle new venue
    if params[:concert][:concert_venue_id].blank? && params[:concert][:new_venue_name].present?
      new_venue = ConcertVenue.find_or_create_by!(
        name: params[:concert][:new_venue_name]
      ) do |v|
        v.city = params[:concert][:new_venue_city]
        v.state = params[:concert][:new_venue_state]
      end
      modified_params[:concert_venue_id] = new_venue.id
    end
    
    # Handle new artists in performances
    if modified_params[:concert_performances_attributes].present?
      modified_params[:concert_performances_attributes].each do |key, perf_params|
        if perf_params[:concert_artist_id].blank? && params[:concert][:concert_performances_attributes][key][:new_artist_name].present?
          new_artist = ConcertArtist.find_or_create_by!(
            name: params[:concert][:concert_performances_attributes][key][:new_artist_name]
          )
          perf_params[:concert_artist_id] = new_artist.id
        end
      end
    end
    
    modified_params
  end
end