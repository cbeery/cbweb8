# app/controllers/admin/concert_artists_controller.rb
class Admin::ConcertArtistsController < Admin::BaseController
  before_action :set_artist, only: [:show]  # Make sure this says set_artist, not set_venue!
  
  def index
    @artists = ConcertArtist.left_joins(:concerts)
                           .group('concert_artists.id')
                           .select('concert_artists.*, COUNT(DISTINCT concerts.id) as concerts_count')
                           .order(Arel.sql('concerts_count DESC'), 'concert_artists.name ASC')
                           .page(params[:page])
                           .per(50)
  end
  
  def show
    @concerts = @artist.concerts
                      .includes(:concert_venue, :concert_artists)
                      .recent
                      .page(params[:page])
    
    # Statistics - Fixed with Arel.sql
    @stats = {
      total_concerts: @artist.concerts.count,
      venues_played: @artist.concerts.distinct.count(:concert_venue_id),
      first_show: @artist.concerts.minimum(:played_on),
      last_show: @artist.concerts.maximum(:played_on),
      most_played_venue: @artist.concerts
                               .joins(:concert_venue)
                               .group('concert_venues.id', 'concert_venues.name')
                               .order(Arel.sql('COUNT(concerts.id) DESC'))
                               .limit(1)
                               .pluck(Arel.sql('concert_venues.name, COUNT(concerts.id)'))
                               .first
    }
    
    # Frequent collaborators - Fixed with Arel.sql
    @collaborators = ConcertArtist.joins(:concert_performances)
                                  .where(concert_performances: { 
                                    concert_id: @artist.concert_ids 
                                  })
                                  .where.not(id: @artist.id)
                                  .group('concert_artists.id')
                                  .select('concert_artists.*, COUNT(*) as shared_concerts')
                                  .order(Arel.sql('shared_concerts DESC'))
                                  .limit(10)
    
    # Venues breakdown - Fixed with Arel.sql
    @venues_breakdown = @artist.concerts
                              .joins(:concert_venue)
                              .group('concert_venues.id', 'concert_venues.name', 'concert_venues.city', 'concert_venues.state')
                              .order(Arel.sql('COUNT(concerts.id) DESC'))
                              .pluck(Arel.sql('concert_venues.id, concert_venues.name, concert_venues.city, concert_venues.state, COUNT(concerts.id)'))
  end
  
  def new
    @artist = ConcertArtist.new
  end
  
  def create
    @artist = ConcertArtist.new(artist_params)
    if @artist.save
      redirect_to admin_concert_artist_path(@artist), notice: 'Artist was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_artist
    @artist = ConcertArtist.find(params[:id])
  end
  
  def artist_params
    params.require(:concert_artist).permit(:name)
  end
end