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
    # Fetch last 5 movie viewings (not unique movies - can include same movie multiple times)
    @recent_viewings = Viewing.includes(movie: :movie_posters)
                              .order(viewed_on: :desc)
                              .limit(5)
    
    # Fetch last 5 books read (completed reads)
    @recent_readings = BookRead.includes(book: :cover_image_attachment)
                               .where.not(finished_on: nil)
                               .order(finished_on: :desc)
                               .limit(5)
    
    # Movie stats for footer
    @movies_this_year = Viewing.where(
      viewed_on: Date.current.beginning_of_year..Date.current.end_of_year
    ).count
    
    # Next book to read
    @next_book = Book.want_to_read.order(created_at: :desc).first
  end

end