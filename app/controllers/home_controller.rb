# app/controllers/home_controller.rb
class HomeController < ApplicationController
  def index
    @recent_movies = Movie.joins(:viewings)
                          .select('movies.*, MAX(viewings.viewed_on) as last_viewed_date')
                          .group('movies.id')
                          .order('last_viewed_date DESC')
                          .limit(5)
    # render :index4                          
  end
  
  def test1
    # Card grid layout example
    @recent_movies = Movie.joins(:viewings)
                          .select('movies.*, MAX(viewings.viewed_on) as last_viewed_date')
                          .group('movies.id')
                          .order('last_viewed_date DESC')
                          .limit(5)
    
    @top_rated = Movie.where.not(rating: nil)
                      .order(rating: :desc)
                      .limit(6)
  end
  
  def test2
    # Masonry-style layout example
    @all_movies = Movie.includes(:movie_posters, :viewings)
                       .joins(:viewings)
                       .distinct
                       .order('viewings.viewed_on DESC')
                       .limit(15)
  end
  
  def test3
    # Dashboard-style layout with stats
    @recent_movies = Movie.joins(:viewings)
                          .select('movies.*, viewings.viewed_on, viewings.rewatch')
                          .order('viewings.viewed_on DESC')
                          .limit(5)
    
    @stats = {
      total_movies: Movie.count,
      total_viewings: Viewing.count,
      movies_this_month: Viewing.where(viewed_on: Date.current.beginning_of_month..Date.current.end_of_month).count,
      avg_rating: Movie.where.not(rating: nil).average(:rating)&.round(2)
    }
  end
  
  def test4
    # Mixed content grid - equal prominence
    @recent_movies = Movie.joins(:viewings)
                          .includes(:movie_posters, :viewings)
                          .distinct
                          .order('viewings.viewed_on DESC')
                          .limit(5)
    @last_movie_poster = @recent_movies.first&.movie_posters&.first
  end
  
  def test5
    # Hero card layout with supporting cards
    @recent_movies = Movie.joins(:viewings)
                          .includes(:movie_posters, :viewings)
                          .distinct
                          .order('viewings.viewed_on DESC')
                          .limit(5)
    @last_movie_poster = @recent_movies.first&.movie_posters&.first
  end
  
  def test6
    # Bento box layout - varied card sizes
    @recent_movies = Movie.joins(:viewings)
                          .includes(:movie_posters, :viewings)
                          .distinct
                          .order('viewings.viewed_on DESC')
                          .limit(5)
    @last_movie_poster = @recent_movies.first&.movie_posters&.first
  end
  
  def test7
    # Timeline/feed style layout
    @recent_movies = Movie.joins(:viewings)
                          .includes(:movie_posters, :viewings)
                          .distinct
                          .order('viewings.viewed_on DESC')
                          .limit(5)
    @last_movie_poster = @recent_movies.first&.movie_posters&.first
  end
  
  def test8
    # Compact widget grid
    @recent_movies = Movie.joins(:viewings)
                          .includes(:movie_posters, :viewings)
                          .distinct
                          .order('viewings.viewed_on DESC')
                          .limit(5)
    @last_movie_poster = @recent_movies.first&.movie_posters&.first
  end
  
  def test9
    # Magazine-style layout
    @recent_movies = Movie.joins(:viewings)
                          .includes(:movie_posters, :viewings)
                          .distinct
                          .order('viewings.viewed_on DESC')
                          .limit(5)
    @last_movie_poster = @recent_movies.first&.movie_posters&.first
  end

  def test11
    # Grid and flex demo page
    # You can add any test data here if needed
    
    # Example data for the dashboard section
    @stats = [
      { label: 'Total Users', value: '12,543', trend: '↑ 12%', trend_positive: true },
      { label: 'Revenue', value: '$48,291', trend: '↑ 8%', trend_positive: true },
      { label: 'Orders', value: '892', trend: '↓ 3%', trend_positive: false },
      { label: 'Conversion', value: '3.2%', trend: '↑ 0.5%', trend_positive: true }
    ]
    
    # Example items for grid demos (optional)
    @items = (1..10).to_a
  end

  def test12
    load_dashboard_data
  end

  def test13
    # Alternative 1: Minimalist List with Thumbnail
    load_dashboard_data
  end

  def test14
    # Alternative 2: Hero + List Pattern
    load_dashboard_data
  end

  def test15
    # Alternative 3: Horizontal Scroll Gallery
    load_dashboard_data
  end

  def test16
    # Alternative 4: Compact Table/List Hybrid
    load_dashboard_data
  end

  def test17
    # Alternative 5: Split Layout (Image + Content Separate)
    load_dashboard_data
  end

  def test18
    # Alternative 6: Table/List with Tiny Thumbnails (16x24px)
    load_dashboard_data
  end

  def test19
    # Alternative 7: Table/List with Small Thumbnails (24x32px)
    load_dashboard_data
  end

  def test20
    # Alternative 8: Table with Medium Thumbnails (32x44px, optimized padding)
    load_dashboard_data
  end

  def test21
    # Alternative 9: Table with Larger Thumbnails (36x48px, minimal padding)
    load_dashboard_data
  end

  # Legacy homepage recreations (for reference/comparison with Bootstrap version)
  def legacy_homepage
    # Only use what we KNOW exists - Movies and Viewings
    @recent_movies = Movie.includes(:movie_posters, :viewings)
                          .joins(:viewings)
                          .order('viewings.viewed_on DESC')
                          .distinct
                          .limit(10)
    
    @movies_this_year = Viewing.where(
      viewed_on: Date.current.beginning_of_year..Date.current.end_of_year
    ).count rescue 0
    
    # Mock data for music (since Last.fm isn't set up)
    @lastfm_last_month = [
      { name: 'Shiner', playcount: 38 },
      { name: 'Curling', playcount: 35 },
      { name: 'The Beths', playcount: 26 },
      { name: 'The Lemonheads', playcount: 21 },
      { name: 'The Lemon Twigs', playcount: 20 }
    ]
    
    @lastfm_last_year = [
      { name: 'The Lemon Twigs', playcount: 406 },
      { name: 'R.E.M.', playcount: 159 },
      { name: 'Shiner', playcount: 138 },
      { name: 'Curling', playcount: 132 },
      { name: 'Castor', playcount: 118 }
    ]
    
    # Use the minimal view that doesn't assume anything else exists
    render 'home/legacy/homepage_minimal'
  end

  def legacy_homepage_modern
    # Reuse the same simple data
    legacy_homepage
    render 'home/legacy/homepage_modern_minimal'
  end

  private

  def load_dashboard_data
    # Shared data loading for test13-17
    @recent_viewings = Viewing.includes(movie: :movie_posters)
                              .order(viewed_on: :desc)
                              .limit(5)
    
    @recent_readings = BookRead.includes(book: :cover_image_attachment)
                               .where.not(finished_on: nil)
                               .order(finished_on: :desc)
                               .limit(5)
    
    @movies_this_year = Viewing.where(
      viewed_on: Date.current.beginning_of_year..Date.current.end_of_year
    ).count
    
    @books_this_year = BookRead.where(
      finished_on: Date.current.beginning_of_year..Date.current.end_of_year
    ).count
    
    @next_book = Book.want_to_read.order(created_at: :desc).first
  end

  def setup_legacy_data
    # Movies (theater) - Get recent viewings, then get unique movies
    recent_theater_viewings = Viewing.includes(movie: :movie_posters)
                                     .where(location: 'theater')
                                     .order(viewed_on: :desc)
                                     .limit(20)
    
    # Get unique movies while preserving order
    seen_movie_ids = Set.new
    @recent_movies = recent_theater_viewings.map(&:movie).select do |movie|
      seen_movie_ids.add?(movie.id)
    end.first(5)
    
    @last_movie = @recent_movies.first
    @movies_this_year = Viewing.where(
      location: 'theater',
      viewed_on: Date.current.beginning_of_year..Date.current.end_of_year
    ).count
    
    # Movies (home/Netflix) - Same approach
    recent_home_viewings = Viewing.includes(movie: :movie_posters)
                                  .where(location: 'home')
                                  .order(viewed_on: :desc)
                                  .limit(20)
    
    seen_home_ids = Set.new
    @home_movies = recent_home_viewings.map(&:movie).select do |movie|
      seen_home_ids.add?(movie.id)
    end.first(5)
    
    @last_home_movie = @home_movies.first
    
    # Books - Same fix for books
    recent_reads = BookRead.includes(book: :cover_image_attachment)
                           .where.not(finished_on: nil)
                           .order(finished_on: :desc)
                           .limit(20)
    
    seen_book_ids = Set.new
    @recent_books = recent_reads.map(&:book).select do |book|
      seen_book_ids.add?(book.id)
    end.first(5)
    
    @last_book = @recent_books.first
    
    # Last.fm data (mock for now - replace with actual API data)
    @lastfm_last_month = [
      { name: 'Shiner', playcount: 38, percentage: 100, url: 'https://www.last.fm/music/Shiner' },
      { name: 'Curling', playcount: 35, percentage: 92, url: 'https://www.last.fm/music/Curling' },
      { name: 'The Beths', playcount: 26, percentage: 68, url: 'https://www.last.fm/music/The+Beths' },
      { name: 'The Lemonheads', playcount: 21, percentage: 55, url: 'https://www.last.fm/music/The+Lemonheads' },
      { name: 'The Lemon Twigs', playcount: 20, percentage: 52, url: 'https://www.last.fm/music/The+Lemon+Twigs' },
      { name: 'John Davis', playcount: 19, percentage: 50, url: 'https://www.last.fm/music/John+Davis' },
      { name: 'Little Truck', playcount: 19, percentage: 50, url: 'https://www.last.fm/music/Little+Truck' },
      { name: 'The Life and Times', playcount: 19, percentage: 50, url: 'https://www.last.fm/music/The+Life+and+Times' },
      { name: 'Art Garfunkel', playcount: 18, percentage: 47, url: 'https://www.last.fm/music/Art+Garfunkel' },
      { name: 'Big Star', playcount: 18, percentage: 47, url: 'https://www.last.fm/music/Big+Star' }
    ]
    
    @lastfm_last_year = [
      { name: 'The Lemon Twigs', playcount: 406, percentage: 100, url: 'https://www.last.fm/music/The+Lemon+Twigs' },
      { name: 'R.E.M.', playcount: 159, percentage: 39, url: 'https://www.last.fm/music/R.E.M.' },
      { name: 'Shiner', playcount: 138, percentage: 33, url: 'https://www.last.fm/music/Shiner' },
      { name: 'Curling', playcount: 132, percentage: 32, url: 'https://www.last.fm/music/Curling' },
      { name: 'Castor', playcount: 118, percentage: 29, url: 'https://www.last.fm/music/Castor' },
      { name: 'American Darlings', playcount: 104, percentage: 25, url: 'https://www.last.fm/music/American+Darlings' },
      { name: 'Van Halen', playcount: 99, percentage: 24, url: 'https://www.last.fm/music/Van+Halen' },
      { name: 'MJ Lenderman', playcount: 80, percentage: 19, url: 'https://www.last.fm/music/MJ+Lenderman' },
      { name: 'The Life and Times', playcount: 77, percentage: 18, url: 'https://www.last.fm/music/The+Life+and+Times' },
      { name: 'Tame Impala', playcount: 74, percentage: 18, url: 'https://www.last.fm/music/Tame+Impala' }
    ]
    
    # Concerts (mock data - replace with actual model data)
    @recent_concerts = [
      { date: Date.parse('2025-10-16'), artists: ['Parcels', 'The Lemon Twigs'], location: 'Morrison, CO' },
      { date: Date.parse('2025-10-15'), artists: ['Shiner', 'No Fauna', 'Brass Tags'], location: 'Denver, CO' },
      { date: Date.parse('2025-09-29'), artists: ['Alkaline Trio', 'Public Opinion'], location: 'Boulder, CO' },
      { date: Date.parse('2025-09-19'), artists: ['Sunny Day Real Estate', 'Cursive'], location: 'Boulder, CO' },
      { date: Date.parse('2025-09-02'), artists: ['Pixies', 'Spoon'], location: 'Morrison, CO' }
    ]
  end

end