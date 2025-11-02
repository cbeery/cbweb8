# app/controllers/admin/movies_controller.rb
class Admin::MoviesController < Admin::BaseController
  before_action :set_movie, only: [:show, :edit, :update, :tmdb_lookup, :tmdb_search, :update_from_tmdb, :tmdb_posters, :select_poster]
  
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
              else # 'watched'
                @movies.left_joins(:viewings)
                       .group('movies.id')
                       .order('MAX(viewings.viewed_on) DESC NULLS LAST')
              end
  end
  
  def show
    @viewings = @movie.viewings.order(viewed_on: :desc)
    @poster = @movie.primary_poster
  end
  
  def edit
  end
  
  def update
    if @movie.update(movie_params)
      # If poster_url is provided, create or update the poster
      if params[:movie][:poster_url].present?
        poster = @movie.movie_posters.find_or_initialize_by(url: params[:movie][:poster_url])
        if poster.new_record?
          poster.source = 'manual'
          poster.primary = @movie.movie_posters.empty?
          poster.save
        end
      end
      
      redirect_to admin_movie_path(@movie), notice: 'Movie was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  # GET /admin/movies/:id/tmdb_lookup
  # Initial modal load - shows TMDB movie if tmdb_id exists, or search form
  def tmdb_lookup
    if @movie.tmdb_id.present?
      @tmdb_movie = TmdbService.get_movie(@movie.tmdb_id)
      @credits = TmdbService.get_movie_credits(@movie.tmdb_id)
      @director = @credits&.dig('crew')&.find { |c| c['job'] == 'Director' }
    end
    
    render layout: false
  end
  
  # POST /admin/movies/:id/tmdb_search
  # Search TMDB by movie name
  def tmdb_search
    query = params[:query]
    @search_results = TmdbService.search_movies(query)
    
    # Enhance results with director info
    @search_results.each do |result|
      credits = TmdbService.get_movie_credits(result['id'])
      director = credits&.dig('crew')&.find { |c| c['job'] == 'Director' }
      result['director_name'] = director&.dig('name')
    end
    
    render layout: false
  end
  
  # PATCH /admin/movies/:id/update_from_tmdb
  # Update movie with selected TMDB data (director + tmdb_id)
  def update_from_tmdb
    tmdb_id = params[:tmdb_id]
    
    credits = TmdbService.get_movie_credits(tmdb_id)
    director = credits&.dig('crew')&.find { |c| c['job'] == 'Director' }
    
    if @movie.update(tmdb_id: tmdb_id, director: director&.dig('name'))
      # Now fetch and show posters
      @posters = TmdbService.get_movie_images(tmdb_id, language: 'en')
      
      # Filter for en-US language specifically
      @posters = @posters.select { |p| p['iso_639_1'] == 'en' }
      
      @total_count = @posters.size
      @posters = @posters.first(20)
      
      render :tmdb_posters, layout: false
    else
      render json: { error: 'Failed to update movie' }, status: :unprocessable_entity
    end
  end
  
  # GET /admin/movies/:id/tmdb_posters
  # Show poster selection grid (called after update_from_tmdb or directly)
  def tmdb_posters
    @posters = TmdbService.get_movie_images(@movie.tmdb_id, language: 'en')
    
    # Filter for en-US language specifically
    @posters = @posters.select { |p| p['iso_639_1'] == 'en' }
    
    @total_count = @posters.size
    @posters = @posters.first(20)
    
    render layout: false
  end
  
  # POST /admin/movies/:id/select_poster
  # Save selected poster from TMDB
  def select_poster
    poster_path = params[:poster_path]
    poster_url = TmdbService.poster_url(poster_path, size: 'original')
    
    # First, check if this exact URL already exists for this movie
    existing_poster = @movie.movie_posters.find_by(url: poster_url)
    
    if existing_poster
      # Just make this existing poster primary
      poster = existing_poster
      poster.update!(primary: true, source: 'tmdb')
    else
      # Find the current primary poster
      current_primary = @movie.movie_posters.find_by(primary: true)
      
      if current_primary
        # Update the existing primary poster with new URL
        poster = current_primary
        poster.update!(url: poster_url, source: 'tmdb')
      else
        # No primary poster exists, create new one
        poster = @movie.movie_posters.create!(
          url: poster_url,
          source: 'tmdb',
          primary: true
        )
      end
    end
    
    # Ensure only this poster is primary
    @movie.movie_posters.where.not(id: poster.id).update_all(primary: false)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("tmdb_modal", '<turbo-frame id="tmdb_modal"></turbo-frame>'),
          turbo_stream.update("movie_#{@movie.id}_poster", 
            partial: "admin/movies/poster", 
            locals: { movie: @movie, poster: poster }),
          turbo_stream.update("movie_#{@movie.id}_director", 
            partial: "admin/movies/director_field",
            locals: { movie: @movie })
        ]
      end
      format.html { redirect_to admin_movie_path(@movie), notice: 'Poster updated successfully.' }
    end
  end
  
  private
  
  def set_movie
    @movie = Movie.find(params[:id])
  end
  
  def movie_params
    params.require(:movie).permit(:title, :director, :year, :rating, :score, :review, :url)
  end
end
