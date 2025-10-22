class Admin::ConcertVenuesController < Admin::BaseController
  def index
    @venues = ConcertVenue.left_joins(:concerts)
                         .group('concert_venues.id')
                         .order('COUNT(concerts.id) DESC')
                         .page(params[:page])
  end
  
  def show
    @venue = ConcertVenue.find(params[:id])
    @concerts = @venue.concerts
                     .includes(:concert_artists)
                     .recent
                     .page(params[:page])
  end
end
