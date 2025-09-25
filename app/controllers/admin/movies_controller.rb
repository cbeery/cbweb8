# app/controllers/admin/movies_controller.rb
class Admin::MoviesController < Admin::BaseController  # Changed from ApplicationController

  before_action :set_movie, only: [:show]
  
  def index
    @movies = Movie.includes(:movie_posters, :viewings)
    
    # Add view mode handling
    @view_mode = params[:view] || 'table'
    @view_mode = 'table' unless %w[grid table table_with_poster].include?(@view_mode)
    
    if params[:search].present?
      @movies = @movies.where("title ILIKE ?", "%#{params[:search]}%")
    end
    
    @movies = case params[:sort]
              when 'title'
                @movies.order(:title)
              when 'year'
                @movies.order(year: :desc, title: :asc)
              when 'rating'
                @movies.order(rating: :desc, title: :asc)
              else 'watched'
                @movies.left_joins(:viewings)
                       .group('movies.id')
                       .order('MAX(viewings.viewed_on) DESC NULLS LAST')
              end
  end
  
  def show
    @viewings = @movie.viewings.order(viewed_on: :desc)
    @poster = @movie.movie_posters.first
  end
  
  private
  
  def set_movie
    @movie = Movie.find(params[:id])
  end
  
end