# app/controllers/home_controller.rb
class HomeController < ApplicationController
  def index
    @recent_movies = Movie.joins(:viewings)
                          .select('movies.*, MAX(viewings.viewed_on) as last_viewed_date')
                          .group('movies.id')
                          .order('last_viewed_date DESC')
                          .limit(5)
    render :index4                          
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
end