class Admin::Concerts::VenuesController < Admin::BaseController
  before_action :set_venue, only: [:show, :edit, :update]

  def index
    @venues = ConcertVenue.left_joins(:concerts)
                         .group('concert_venues.id')
                         .select('concert_venues.*, COUNT(DISTINCT concerts.id) as concerts_count')
                         .order(Arel.sql('concerts_count DESC'), 'concert_venues.name ASC')
                         .page(params[:page])
                         .per(50)
  end

  def show
    @concerts = @venue.concerts
                     .includes(:concert_artists)
                     .recent
                     .page(params[:page])

    # Statistics - Fixed with Arel.sql for safety
    @stats = {
      total_concerts: @venue.concerts.count,
      total_artists: @venue.concerts.joins(:concert_artists).distinct.count('concert_artists.id'),
      first_show: @venue.concerts.minimum(:played_on),
      last_show: @venue.concerts.maximum(:played_on),
      busiest_year: @venue.concerts
                         .group(Arel.sql('EXTRACT(YEAR FROM played_on)'))
                         .order(Arel.sql('COUNT(*) DESC'))
                         .limit(1)
                         .count
                         .first
    }

    # Most frequent artists at this venue - Fixed with Arel.sql
    @frequent_artists = ConcertArtist.joins(:concerts)
                                    .where(concerts: { concert_venue_id: @venue.id })
                                    .group('concert_artists.id')
                                    .select('concert_artists.*, COUNT(concerts.id) as venue_concerts')
                                    .order(Arel.sql('venue_concerts DESC'))
                                    .limit(10)

    # Concerts by year - Fixed with Arel.sql
    @concerts_by_year = @venue.concerts
                             .group(Arel.sql('EXTRACT(YEAR FROM played_on)'))
                             .order(Arel.sql('EXTRACT(YEAR FROM played_on) DESC'))
                             .count
  end

  def new
    @venue = ConcertVenue.new
  end

  def create
    @venue = ConcertVenue.new(venue_params)
    if @venue.save
      redirect_to admin_concerts_venue_path(@venue), notice: 'Venue was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @venue.update(venue_params)
      redirect_to admin_concerts_venue_path(@venue), notice: 'Venue was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_venue
    @venue = ConcertVenue.find(params[:id])
  end

  def venue_params
    params.require(:concert_venue).permit(:name, :city, :state)
  end
end
