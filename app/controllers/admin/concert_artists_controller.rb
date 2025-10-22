class Admin::ConcertArtistsController < Admin::BaseController
  def index
    @artists = ConcertArtist.joins(:concerts)
                           .group('concert_artists.id')
                           .order('COUNT(concerts.id) DESC')
                           .page(params[:page])
  end
  
  def show
    @artist = ConcertArtist.find(params[:id])
    @concerts = @artist.concerts
                      .includes(:concert_venue, :concert_artists)
                      .recent
                      .page(params[:page])
  end
end
