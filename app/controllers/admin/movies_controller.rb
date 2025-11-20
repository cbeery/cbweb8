# app/controllers/admin/movies_controller.rb
class Admin::MoviesController < Admin::BaseController
  before_action :set_movie, only: [:show, :edit, :update, :destroy, :enrich, :enrich_step2, :enrich_step3, :process_enrichment, :tmdb_lookup, :tmdb_search, :update_from_tmdb, :tmdb_posters, :select_poster]
  
  def index
    @movies = Movie.includes(:movie_posters, :viewings)
    
    # Add view mode handling
    @view_mode = params[:view] || 'table'
    @view_mode = 'table' unless %w[grid table table_with_poster].include?(@view_mode)
    
    # Filter for unenriched movies if requested
    if params[:filter] == 'unenriched'
      @movies = @movies.where(director: [nil, ''])
    end
    
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
              else # 'watched' - default
                @movies.left_joins(:viewings)
                       .group('movies.id')
                       .order('MAX(viewings.viewed_on) DESC NULLS LAST')
              end
    
    @movies = @movies.page(params[:page]).per(50)
  end

  def show
    @viewings = @movie.viewings.includes(:theater, film_series_event: :film_series).order(viewed_on: :desc)
    @poster = @movie.primary_poster
  end
  
  def new
    @movie = Movie.new
  end
  
  def create
    @movie = Movie.new(movie_params)
    
    if @movie.save
      handle_poster_upload
      redirect_to admin_movie_path(@movie), notice: 'Movie was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @movie.update(movie_params)
      handle_poster_upload
      redirect_to admin_movie_path(@movie), notice: 'Movie was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @movie.destroy
    redirect_to admin_movies_path, notice: 'Movie was successfully deleted.'
  end
  
  # GET /admin/movies/:id/enrich
  # Step 1: TMDB lookup for director and year
  def enrich
    @viewing = @movie.viewings.order(viewed_on: :desc).first || @movie.viewings.build
    
    if @movie.director.blank? && @movie.tmdb_id.blank?
      # Need to find TMDB data first
      render :enrich_tmdb
    else
      # Skip to step 2 if we already have director
      redirect_to enrich_step2_admin_movie_path(@movie)
    end
  end
  
  # GET /admin/movies/:id/enrich_step2  
  # Step 2: Set viewing details (location, theater, film series)
  def enrich_step2
    @viewing = @movie.viewings.order(viewed_on: :desc).first || @movie.viewings.build
    @theaters = Theater.order(:name)
    @film_series = FilmSeries.order(:name)
    @film_series_events = @viewing.film_series_event&.film_series&.film_series_events&.order(started_on: :desc) || []
  end
  
  # GET /admin/movies/:id/enrich_step3
  # Step 3: Select poster
  def enrich_step3
    if @movie.tmdb_id.present?
      @posters = TmdbService.get_movie_images(@movie.tmdb_id, language: 'en')
      @posters = @posters.select { |p| p['iso_639_1'] == 'en' }
      @total_count = @posters.size
      @posters = @posters.first(20)
    else
      @posters = []
    end
  end
  
  # PATCH /admin/movies/:id/process_enrichment
  # Process the enrichment form submission
  def process_enrichment
    ActiveRecord::Base.transaction do
      # Update movie with TMDB data if provided
      if params[:tmdb_id].present? && @movie.tmdb_id != params[:tmdb_id]
        @movie.update!(tmdb_id: params[:tmdb_id])
        
        # Fetch and update director
        if params[:fetch_director] == 'true'
          credits = TmdbService.get_movie_credits(params[:tmdb_id])
          director = credits&.dig('crew')&.find { |c| c['job'] == 'Director' }
          @movie.update!(director: director['name']) if director
        end
      end
      
      # Update or create viewing with details
      if params[:viewing].present?
        viewing = @movie.viewings.find_or_initialize_by(id: params[:viewing][:id])
        viewing.update!(viewing_enrichment_params)
      end
      
      # Handle poster selection
      if params[:poster_path].present?
        save_poster_from_tmdb(params[:poster_path])
      end
      
      redirect_to admin_movie_path(@movie), notice: 'Movie successfully enriched!'
    end
  rescue => e
    redirect_to admin_movie_path(@movie), alert: "Error enriching movie: #{e.message}"
  end
  
  # Existing TMDB methods...
  def tmdb_lookup
    if @movie.tmdb_id.present?
      @tmdb_movie = TmdbService.get_movie(@movie.tmdb_id)
      @credits = TmdbService.get_movie_credits(@movie.tmdb_id)
      @director = @credits&.dig('crew')&.find { |c| c['job'] == 'Director' }
    end
    
    render layout: false
  end
  
  def tmdb_search
    query = params[:query]
    @search_results = TmdbService.search_movies(query)
    
    @search_results.each do |result|
      credits = TmdbService.get_movie_credits(result['id'])
      director = credits&.dig('crew')&.find { |c| c['job'] == 'Director' }
      result['director_name'] = director&.dig('name')
    end
    
    render layout: false
  end
  
  def update_from_tmdb
    tmdb_id = params[:tmdb_id]
    
    credits = TmdbService.get_movie_credits(tmdb_id)
    director = credits&.dig('crew')&.find { |c| c['job'] == 'Director' }
    
    if @movie.update(tmdb_id: tmdb_id, director: director&.dig('name'))
      @posters = TmdbService.get_movie_images(tmdb_id, language: 'en')
      @posters = @posters.select { |p| p['iso_639_1'] == 'en' }
      @total_count = @posters.size
      @posters = @posters.first(20)
      
      render :tmdb_posters, layout: false
    else
      render json: { error: 'Failed to update movie' }, status: :unprocessable_entity
    end
  end
  
  def tmdb_posters
    @posters = TmdbService.get_movie_images(@movie.tmdb_id, language: 'en')
    @posters = @posters.select { |p| p['iso_639_1'] == 'en' }
    @total_count = @posters.size
    @posters = @posters.first(20)
    
    render layout: false
  end
  
  def select_poster
    save_poster_from_tmdb(params[:poster_path])
    
    respond_to do |format|
      format.html { redirect_to admin_movie_path(@movie), notice: 'Poster updated!' }
      format.json { render json: { success: true, poster_url: @movie.primary_poster&.display_url } }
    end
  end
  
  private
  
  def set_movie
    @movie = Movie.find(params[:id])
  end
  
  def movie_params
    params.require(:movie).permit(:title, :director, :year, :rating, :runtime, :imdb_id, :tmdb_id, :letterboxd_id, :notes)
  end
  
  def viewing_enrichment_params
    params.require(:viewing).permit(:viewed_on, :location, :theater_id, :film_series_event_id, :notes, :rewatch, :price, :format, :time)
  end
  
  def handle_poster_upload
    if params[:movie][:poster_file].present?
      poster = @movie.movie_posters.create!(
        source: 'manual',
        primary: true
      )
      poster.image.attach(params[:movie][:poster_file])
    elsif params[:movie][:poster_url].present?
      @movie.movie_posters.create!(
        url: params[:movie][:poster_url],
        source: 'manual',
        primary: true
      )
    end
  end
  
  def save_poster_from_tmdb(poster_path)
    poster_url = TmdbService.poster_url(poster_path, size: 'original')
    
    existing_poster = @movie.movie_posters.find_by(url: poster_url)
    
    if existing_poster
      existing_poster.update!(primary: true)
    else
      @movie.movie_posters.update_all(primary: false)
      @movie.movie_posters.create!(
        url: poster_url,
        source: 'tmdb',
        primary: true
      )
    end
  end
end
