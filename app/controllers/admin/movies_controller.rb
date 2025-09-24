class Admin::MoviesController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_movie, only: [:show]
  # before_action :set_movie, only: [:show, :edit, :update, :destroy]
  
  def index
    @movies = Movie.includes(:movie_posters, :viewings)
    
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
              when 'watched'
                @movies.left_joins(:viewings)
                       .group('movies.id')
                       .order('MAX(viewings.viewed_on) DESC NULLS LAST')
              else
                @movies.order(created_at: :desc)
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
  
  def authenticate_admin!
    redirect_to root_path unless current_user&.admin?
  end
end