class Admin::Concerts::DashboardController < Admin::BaseController
  def index
    @total_concerts = Concert.count
    @total_artists = ConcertArtist.count
    @total_venues = ConcertVenue.count

    @recent_concerts = Concert.includes(:concert_venue, :concert_artists)
                              .recent
                              .limit(5)

    @top_artists = ConcertArtist.joins(:concerts)
                                .select('concert_artists.*, COUNT(concerts.id) as concert_count')
                                .group('concert_artists.id')
                                .order('concert_count DESC')
                                .limit(5)
  end
end
