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
    # If we don't have a TMDB ID, show the TMDB search form
    if @movie.tmdb_id.blank?
      render :enrich_tmdb
      return
    end
    
    # If we have TMDB ID but no director, fetch it silently
    if @movie.director.blank? && @movie.tmdb_id.present?
      fetch_director_from_tmdb
    end
    
    # Go directly to step 2 (viewing details)
    redirect_to enrich_step2_admin_movie_path(@movie)
  end
  
  # GET /admin/movies/:id/enrich_step2  
  # Step 2: Set viewing details (location, theater, film series)
  def enrich_step2
    # Find or build a viewing, ensuring viewed_on is set
    @viewing = @movie.viewings.order(viewed_on: :desc).first
    if @viewing.nil?
      @viewing = @movie.viewings.build(viewed_on: Date.current)
    elsif @viewing.viewed_on.nil?
      @viewing.viewed_on = Date.current
    end
    
    @theaters = Theater.alphabetical
    @film_series = FilmSeries.alphabetical
    
    # Load events for the selected series if present
    if @viewing.film_series_event_id.present?
      series_id = @viewing.film_series_event.film_series_id
      @film_series_events = FilmSeriesEvent.where(film_series_id: series_id).recent
    else
      @film_series_events = []
    end
  end
    
  # GET /admin/movies/:id/enrich_step3
  # Step 3: Select poster
  def enrich_step3
    if @movie.tmdb_id.present?
      @posters = TmdbService.get_movie_images(@movie.tmdb_id, language: 'en')
      @posters = @posters.select { |p| p['iso_639_1'] == 'en' } if @posters
      @total_count = @posters&.size || 0
      @posters = (@posters || []).first(20)
    else
      @posters = []
      @total_count = 0
    end
  end
  
  # PATCH /admin/movies/:id/process_enrichment
  # Process the enrichment form submission
  def process_enrichment
    ActiveRecord::Base.transaction do
      # Update or create viewing with details
      if params[:viewing].present?
        viewing_params = viewing_enrichment_params
        
        # Ensure viewed_on is present
        if viewing_params[:viewed_on].blank?
          viewing_params[:viewed_on] = Date.current
        end
        
        # Find or build viewing
        if params[:viewing][:id].present?
          @viewing = @movie.viewings.find(params[:viewing][:id])
        else
          @viewing = @movie.viewings.build
        end
        
        # Clear location-specific fields if location is 'home'
        if viewing_params[:location] == 'home'
          viewing_params[:theater_id] = nil
          viewing_params[:price] = nil
          viewing_params[:format] = nil
        end
        
        # Update viewing attributes
        @viewing.assign_attributes(viewing_params)
        
        unless @viewing.save
          flash[:alert] = "Error saving viewing: #{@viewing.errors.full_messages.join(', ')}"
          
          # Reload the data needed for the form
          @theaters = Theater.alphabetical
          @film_series = FilmSeries.alphabetical
          if @viewing.film_series_event_id.present?
            series_id = @viewing.film_series_event.film_series_id
            @film_series_events = FilmSeriesEvent.where(film_series_id: series_id).recent
          else
            @film_series_events = []
          end
          
          render :enrich_step2, status: :unprocessable_entity
          return
        end
      end
      
      # If continue_to_posters is true, go to poster selection
      if params[:continue_to_posters] == 'true'
        redirect_to enrich_step3_admin_movie_path(@movie)
      else
        redirect_to admin_movie_path(@movie), notice: 'Movie enrichment completed!'
      end
    end
  rescue => e
    logger.error "Enrichment error: #{e.message}"
    logger.error e.backtrace.join("\n")
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

  # GET /admin/movies/location_icons
  def location_icons
    # No data needed - view uses Viewing.location_options directly
  end

  private
  
  def set_movie
    @movie = Movie.find(params[:id])
  end
  
  def movie_params
    params.require(:movie).permit(:title, :director, :year, :rating, :runtime, :imdb_id, :tmdb_id, :letterboxd_id, :notes)
  end
  
  def viewing_enrichment_params
    # Clean up the params before permitting
    viewing_params = params.require(:viewing).permit(:viewed_on, :location, :theater_id, :film_series_event_id, :notes, :rewatch, :price, :format, :time)
    
    # Ensure viewed_on is a proper date
    if viewing_params[:viewed_on].present?
      begin
        viewing_params[:viewed_on] = Date.parse(viewing_params[:viewed_on].to_s)
      rescue ArgumentError
        viewing_params[:viewed_on] = Date.current
      end
    else
      viewing_params[:viewed_on] = Date.current
    end
    
    viewing_params
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

  def fetch_director_from_tmdb
    return unless @movie.tmdb_id.present?
    
    credits = TmdbService.get_movie_credits(@movie.tmdb_id)
    director = credits&.dig('crew')&.find { |c| c['job'] == 'Director' }
    
    if director
      @movie.update!(director: director['name'])
    end
  rescue => e
    logger.error "Failed to fetch director from TMDB: #{e.message}"
  end
  
  def save_poster_from_tmdb(poster_path)
    return unless poster_path.present?
    
    # Build the full poster URL
    poster_url = "https://image.tmdb.org/t/p/original#{poster_path}"
    
    # Check if we already have this poster
    existing_poster = @movie.movie_posters.find_by(url: poster_url)
    
    if existing_poster
      # Just make it primary
      @movie.movie_posters.update_all(primary: false)
      existing_poster.update!(primary: true)
    else
      # Mark any existing primary posters as non-primary
      @movie.movie_posters.where(primary: true).update_all(primary: false)
      
      # Create new poster record (removed tmdb_path which doesn't exist)
      @movie.movie_posters.create!(
        url: poster_url,
        source: 'tmdb',
        primary: true
      )
    end
  end
end
