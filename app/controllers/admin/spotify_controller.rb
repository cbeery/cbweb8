class Admin::SpotifyController < Admin::BaseController
  before_action :set_playlist, only: [:show, :edit, :update, :destroy, :sync]
  
  def index
    @playlists = SpotifyPlaylist.includes(:spotify_tracks)
    
    # Filtering
    @playlists = @playlists.mixtapes if params[:mixtapes] == 'true'
    @playlists = @playlists.non_mixtapes if params[:mixtapes] == 'false'
    @playlists = @playlists.by_year(params[:year]) if params[:year].present?
    @playlists = @playlists.by_month(params[:month]) if params[:month].present?
    @playlists = @playlists.where(made_by: params[:made_by]) if params[:made_by].present?
    
    # Search
    if params[:q].present?
      @playlists = @playlists.where('name ILIKE ? OR owner_name ILIKE ?', 
                                     "%#{params[:q]}%", "%#{params[:q]}%")
    end
    
    # Sorting
    @playlists = case params[:sort]
    when 'name'
      @playlists.order(:name)
    when 'date_desc'
      @playlists.order(made_on: :desc)
    when 'date_asc'
      @playlists.order(made_on: :asc)
    when 'tracks'
      @playlists.left_joins(:spotify_playlist_tracks)
                .group('spotify_playlists.id')
                .order('COUNT(spotify_playlist_tracks.id) DESC')
    when 'runtime'
      @playlists.order(runtime_ms: :desc)
    when 'recently_synced'
      @playlists.order(last_synced_at: :desc)
    else
      @playlists.order(made_on: :desc)
    end
    
    @playlists = @playlists.page(params[:page]).per(25)
    
    # Get filter options
    @available_years = SpotifyPlaylist.distinct.pluck(:year).compact.sort.reverse
    @available_makers = SpotifyPlaylist.distinct.pluck(:made_by).compact.sort
  end
  
  def show
    @tracks = @playlist.spotify_playlist_tracks
                       .includes(spotify_track: :spotify_artists)
                       .ordered
                       .page(params[:page]).per(50)
  end
  
  def new
    @playlist = SpotifyPlaylist.new(
      made_on: Date.today.beginning_of_month,
      mixtape: params[:mixtape] == 'true'
    )
  end
  
  def create
    @playlist = SpotifyPlaylist.new(playlist_params)
    
    if @playlist.save
      redirect_to admin_spotify_playlist_path(@playlist), 
                  notice: 'Playlist was successfully created. It will sync automatically soon.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @playlist.update(playlist_params)
      redirect_to admin_spotify_playlist_path(@playlist), 
                  notice: 'Playlist was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @playlist.destroy
    redirect_to admin_spotify_playlists_path, 
                notice: 'Playlist was successfully deleted.'
  end
  
  def sync
    sync_status = SyncStatus.create!(
      source_type: 'spotify_single',
      interactive: true,
      user: current_user,
      metadata: { 
        playlist_id: @playlist.id,
        playlist_name: @playlist.name,
        single_playlist: true
      }
    )
    
    # Create a custom job to sync just this playlist
    SpotifySingleSyncJob.perform_later(@playlist.id, sync_status.id)
    
    redirect_to admin_sync_path(sync_status), 
                notice: "Syncing #{@playlist.name}..."
  end

  # If you want to add a controller action to check sync status via AJAX
  def sync_status
    @playlist = SpotifyPlaylist.find(params[:id])
    
    # Find the most recent sync for this playlist
    sync_status = SyncStatus.where(source_type: 'spotify_single')
                           .where("metadata->>'playlist_id' = ?", @playlist.id.to_s)
                           .order(created_at: :desc)
                           .first
    
    if sync_status
      render json: {
        status: sync_status.status,
        started_at: sync_status.started_at,
        completed_at: sync_status.completed_at,
        error_message: sync_status.error_message,
        syncing: sync_status.running?
      }
    else
      render json: { status: 'never_synced', syncing: false }
    end
  end  
  
  def mixtapes_old
    @playlists = SpotifyPlaylist.mixtapes
                                .includes(spotify_playlist_tracks: { 
                                  spotify_track: :spotify_artists 
                                })
    
    # Build tracks collection from mixtapes
    track_ids = SpotifyPlaylistTrack.joins(:spotify_playlist)
                                    .where(spotify_playlists: { mixtape: true })
                                    .distinct
                                    .pluck(:spotify_track_id)
    
    @tracks = SpotifyTrack.where(id: track_ids)
                          .includes(:spotify_artists, spotify_playlist_tracks: :spotify_playlist)
    
    # Search
    if params[:q].present?
      search_term = "%#{params[:q]}%"
      @tracks = @tracks.where(
        'spotify_tracks.title ILIKE ? OR spotify_tracks.artist_text ILIKE ? OR spotify_tracks.album ILIKE ?', 
        search_term, search_term, search_term
      )
    end
    
    # Filters
    if params[:year].present?
      playlist_ids = SpotifyPlaylist.mixtapes.by_year(params[:year]).pluck(:id)
      track_ids = SpotifyPlaylistTrack.where(spotify_playlist_id: playlist_ids)
                                      .distinct.pluck(:spotify_track_id)
      @tracks = @tracks.where(id: track_ids)
    end
    
    if params[:month].present?
      playlist_ids = SpotifyPlaylist.mixtapes.by_month(params[:month]).pluck(:id)
      track_ids = SpotifyPlaylistTrack.where(spotify_playlist_id: playlist_ids)
                                      .distinct.pluck(:spotify_track_id)
      @tracks = @tracks.where(id: track_ids)
    end
    
    if params[:made_by].present?
      playlist_ids = SpotifyPlaylist.mixtapes.where(made_by: params[:made_by]).pluck(:id)
      track_ids = SpotifyPlaylistTrack.where(spotify_playlist_id: playlist_ids)
                                      .distinct.pluck(:spotify_track_id)
      @tracks = @tracks.where(id: track_ids)
    end
    
    if params[:artist].present?
      @tracks = @tracks.by_artist(params[:artist])
    end
    
    if params[:explicit].present?
      @tracks = params[:explicit] == 'true' ? @tracks.explicit : @tracks.where(explicit: false)
    end
    
    if params[:min_popularity].present?
      @tracks = @tracks.where('popularity >= ?', params[:min_popularity].to_i)
    end
    
    # Filter for artists with multiple tracks among mixtapes
    if params[:duplicate_artists] == 'true'
      # Find artists who have more than one track across all mixtapes
      artist_ids_with_multiple_tracks = SpotifyArtist
        .joins(spotify_tracks: :spotify_playlists)
        .where(spotify_playlists: { mixtape: true })
        .group('spotify_artists.id')
        .having('COUNT(DISTINCT spotify_tracks.id) > 1')  # Changed from counting playlists to counting tracks
        .pluck(:id)
      
      @tracks = @tracks.joins(:spotify_artists)
                       .where(spotify_artists: { id: artist_ids_with_multiple_tracks })
                       .distinct
    end

    # Filter for tracks appearing on multiple mixtapes
    if params[:duplicate_tracks] == 'true'
      duplicate_track_ids = SpotifyPlaylistTrack
        .joins(:spotify_playlist)
        .where(spotify_playlists: { mixtape: true })
        .group(:spotify_track_id)
        .having('COUNT(DISTINCT spotify_playlist_id) > 1')
        .pluck(:spotify_track_id)
      
      @tracks = @tracks.where(id: duplicate_track_ids)
    end

    # Sorting
    @tracks = case params[:sort]
    when 'title'
      @tracks.order(:title)
    when 'artist'
      @tracks.order(:artist_sort_text, :title)
    when 'album'
      @tracks.order(:album, :track_number)
    when 'popularity'
      @tracks.order(popularity: :desc)
    when 'duration'
      @tracks.order(duration_ms: :desc)
    when 'added_recently'
      @tracks.joins(:spotify_playlist_tracks)
             .order('spotify_playlist_tracks.created_at DESC')
    else
      # Default: by playlist date and position
      @tracks.joins(spotify_playlist_tracks: :spotify_playlist)
             .order('spotify_playlists.made_on DESC, spotify_playlist_tracks.position')
    end
    
    # For each track, get position and made_by info for display
    @track_display_info = {}
    @tracks.each do |track|
      mixtape_playlists = track.spotify_playlists.mixtapes.includes(:spotify_playlist_tracks)
      
      # Get the most recent playlist this track appears on
      most_recent_playlist = mixtape_playlists.order(made_on: :desc).first
      
      if most_recent_playlist
        playlist_track = track.spotify_playlist_tracks.find_by(spotify_playlist: most_recent_playlist)
        @track_display_info[track.id] = {
          position: playlist_track&.position,
          primary_playlist: most_recent_playlist,
          made_by: most_recent_playlist.made_by,
          all_playlists: mixtape_playlists
        }
      end
    end
    
    @tracks = @tracks.page(params[:page]).per(50)
    
    # Get filter options
    @available_years = SpotifyPlaylist.mixtapes.distinct.pluck(:year).compact.sort.reverse
    @available_months = (1..12).map { |m| [Date::MONTHNAMES[m], m] }
    @available_makers = SpotifyPlaylist.mixtapes.distinct.pluck(:made_by).compact.sort
    
    # Get popular artists for filter
    @popular_artists = SpotifyArtist.joins(:spotify_tracks)
                                    .where(spotify_tracks: { id: track_ids })
                                    .group('spotify_artists.id')
                                    .order('COUNT(spotify_tracks.id) DESC')
                                    .limit(20)
                                    .pluck(:name)
    
    # Stats for display
    @total_tracks = track_ids.count
    @total_runtime_ms = SpotifyTrack.where(id: track_ids).sum(:duration_ms)
    @unique_artists = SpotifyArtist.joins(:spotify_tracks)
                                   .where(spotify_tracks: { id: track_ids })
                                   .distinct.count
  end

  def mixtapes_old_2
    # Cache filter options (these don't change often)
    @available_years = Rails.cache.fetch('mixtapes:years', expires_in: 1.hour) do
      SpotifyPlaylist.mixtapes.distinct.pluck(:year).compact.sort.reverse
    end
    @available_months = (1..12).map { |m| [Date::MONTHNAMES[m], m] }
    @available_makers = Rails.cache.fetch('mixtapes:makers', expires_in: 1.hour) do
      SpotifyPlaylist.mixtapes.distinct.pluck(:made_by).compact.sort
    end
    
    # Start with base playlists query
    @playlists = SpotifyPlaylist.mixtapes
                                .includes(spotify_playlist_tracks: { 
                                  spotify_track: :spotify_artists 
                                })
    
    # Build base filtered query
    base_tracks = build_base_tracks_query(params)
    
    # Get track IDs for stats (before sorting/grouping)
    track_ids = base_tracks.distinct.pluck('spotify_tracks.id')
    @total_tracks = track_ids.count
    
    # Get aggregated stats
    if @total_tracks > 0
      @total_runtime_ms = SpotifyTrack.where(id: track_ids).sum(:duration_ms)
      @unique_artists = SpotifyArtist
                         .joins(:spotify_tracks)
                         .where(spotify_tracks: { id: track_ids })
                         .distinct
                         .count
    else
      @total_runtime_ms = 0
      @unique_artists = 0
    end
    
    # Get popular artists (cached)
    cache_key = [
      'mixtapes:popular_artists',
      params[:year],
      params[:month],
      params[:made_by],
      params[:artist],
      params[:q]
    ].compact
    
    @popular_artists = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      SpotifyArtist
        .joins(:spotify_tracks)
        .where(spotify_tracks: { id: track_ids })
        .group('spotify_artists.id')
        .order(Arel.sql('COUNT(DISTINCT spotify_tracks.id) DESC'))
        .limit(20)
        .pluck(:name)
    end
    
    # Get sorted track IDs based on sort parameter
    sorted_track_ids = get_sorted_track_ids(base_tracks, params[:sort])
    
    # Load tracks with includes in the sorted order
    if sorted_track_ids.any?
      # Use a CASE statement to maintain order
      order_sql = sorted_track_ids.each_with_index.map { |id, idx| 
        "WHEN #{id} THEN #{idx}" 
      }.join(' ')
      
      @tracks = SpotifyTrack
        .where(id: sorted_track_ids)
        .includes(:spotify_artists, spotify_playlist_tracks: :spotify_playlist)
        .order(Arel.sql("CASE spotify_tracks.id #{order_sql} END"))
    else
      @tracks = SpotifyTrack.none
    end
    
    # Paginate
    @tracks = @tracks.page(params[:page]).per(50)
    
    # Build display info
    build_track_display_info
  end

  def mixtapes
    # Cache filter options (these don't change often)
    @available_years = Rails.cache.fetch('mixtapes:years', expires_in: 1.hour) do
      SpotifyPlaylist.mixtapes.distinct.pluck(:year).compact.sort.reverse
    end
    @available_months = (1..12).map { |m| [Date::MONTHNAMES[m], m] }
    @available_makers = Rails.cache.fetch('mixtapes:makers', expires_in: 1.hour) do
      SpotifyPlaylist.mixtapes.distinct.pluck(:made_by).compact.sort
    end
    
    # Add available decades for filter
    @available_decades = Rails.cache.fetch('mixtapes:decades:v3', expires_in: 1.hour) do
      years = SpotifyTrack
        .joins(:spotify_playlists)
        .where(spotify_playlists: { mixtape: true })
        .where.not(release_year: nil)
        .distinct
        .pluck(:release_year)
      
      # Convert years to decades and format for dropdown
      years.map { |year| (year / 10) * 10 }
           .uniq
           .sort
           .reverse
           .map { |decade| ["#{decade}s", decade] }
    end
    
    # Start with base playlists query
    @playlists = SpotifyPlaylist.mixtapes
                                .includes(spotify_playlist_tracks: { 
                                  spotify_track: :spotify_artists 
                                })
    
    # Build base filtered query
    base_tracks = build_base_tracks_query(params)
    
    # Apply decade filter if present
    if params[:decade].present?
      base_tracks = base_tracks.by_decade(params[:decade])
    end
    
    # Get track IDs for stats (before sorting/grouping)
    track_ids = base_tracks.distinct.pluck('spotify_tracks.id')
    @total_tracks = track_ids.count
    
    # Get aggregated stats
    if @total_tracks > 0
      @total_runtime_ms = SpotifyTrack.where(id: track_ids).sum(:duration_ms)
      @unique_artists = SpotifyArtist
                         .joins(:spotify_tracks)
                         .where(spotify_tracks: { id: track_ids })
                         .distinct
                         .count
    else
      @total_runtime_ms = 0
      @unique_artists = 0
    end
    
    # Get popular artists (cached)
    cache_key = [
      'mixtapes:popular_artists',
      params[:year],
      params[:month],
      params[:made_by],
      params[:artist],
      params[:decade],
      params[:q]
    ].compact
    
    @popular_artists = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      SpotifyArtist
        .joins(:spotify_tracks)
        .where(spotify_tracks: { id: track_ids })
        .group('spotify_artists.id')
        .order(Arel.sql('COUNT(DISTINCT spotify_tracks.id) DESC'))
        .limit(20)
        .pluck(:name)
    end
    
    # Get sorted track IDs based on sort parameter (updated with year options)
    sorted_track_ids = get_sorted_track_ids(base_tracks, params[:sort])
    
    # Load tracks with includes in the sorted order
    if sorted_track_ids.any?
      @tracks = SpotifyTrack
        .where(id: sorted_track_ids)
        .includes(:spotify_artists, spotify_playlist_tracks: :spotify_playlist)
        .order(Arel.sql("ARRAY_POSITION(ARRAY[#{sorted_track_ids.join(',')}], spotify_tracks.id)"))
    else
      @tracks = SpotifyTrack.none
    end
    
    build_track_display_info
    
    @tracks = @tracks.page(params[:page]).per(50)
  end

  private
  
  def set_playlist
    @playlist = SpotifyPlaylist.find(params[:id])
  end
  
  def playlist_params
    params.require(:spotify_playlist).permit(:name, :spotify_url, :made_by, :mixtape, :made_on)
  end

  def build_base_tracks_query(params)
    tracks = SpotifyTrack
      .joins(spotify_playlist_tracks: :spotify_playlist)
      .where(spotify_playlists: { mixtape: true })
    
    # Apply filters
    tracks = apply_search_filter(tracks, params[:q])
    tracks = apply_year_filter(tracks, params[:year])
    tracks = apply_month_filter(tracks, params[:month])
    tracks = apply_made_by_filter(tracks, params[:made_by])
    tracks = apply_artist_filter(tracks, params[:artist])
    tracks = apply_explicit_filter(tracks, params[:explicit])
    tracks = apply_popularity_filter(tracks, params[:min_popularity])
    tracks = apply_duplicate_artists_filter(tracks) if params[:duplicate_artists] == 'true'
    tracks = apply_duplicate_tracks_filter(tracks) if params[:duplicate_tracks] == 'true'
    
    tracks
  end

  def get_sorted_track_ids(tracks, sort_param)
    case sort_param
    when 'title'
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MIN(spotify_tracks.title)'))
            .pluck('spotify_tracks.id')
    when 'artist'
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MIN(spotify_tracks.artist_sort_text), MIN(spotify_tracks.title)'))
            .pluck('spotify_tracks.id')
    when 'album'
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MIN(spotify_tracks.album), MIN(spotify_tracks.track_number)'))
            .pluck('spotify_tracks.id')
    when 'year_newest'
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MAX(spotify_tracks.release_year) DESC NULLS LAST'))
            .pluck('spotify_tracks.id')
    when 'year_oldest'
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MIN(spotify_tracks.release_year) ASC NULLS LAST'))
            .pluck('spotify_tracks.id')
    when 'popularity'
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MAX(spotify_tracks.popularity) DESC'))
            .pluck('spotify_tracks.id')
    when 'duration'
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MAX(spotify_tracks.duration_ms) DESC'))
            .pluck('spotify_tracks.id')
    when 'added_recently'
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MAX(spotify_playlist_tracks.created_at) DESC NULLS LAST'))
            .pluck('spotify_tracks.id')
    else
      # Default: by playlist date and position
      tracks.group('spotify_tracks.id')
            .order(Arel.sql('MAX(spotify_playlists.made_on) DESC NULLS LAST, MIN(spotify_playlist_tracks.position)'))
            .pluck('spotify_tracks.id')
    end
  end

  def apply_search_filter(tracks, search_term)
    return tracks if search_term.blank?
    
    term = "%#{search_term}%"
    tracks.where(
      'spotify_tracks.title ILIKE ? OR spotify_tracks.artist_text ILIKE ? OR spotify_tracks.album ILIKE ?',
      term, term, term
    )
  end

  def apply_year_filter(tracks, year)
    return tracks if year.blank?
    
    tracks.where(spotify_playlists: { year: year })
  end

  def apply_month_filter(tracks, month)
    return tracks if month.blank?
    
    tracks.where(spotify_playlists: { month: month })
  end

  def apply_made_by_filter(tracks, made_by)
    return tracks if made_by.blank?
    
    tracks.where(spotify_playlists: { made_by: made_by })
  end

  def apply_artist_filter(tracks, artist)
    return tracks if artist.blank?
    
    # Assuming by_artist is a scope on SpotifyTrack model
    tracks.by_artist(artist)
  end

  def apply_explicit_filter(tracks, explicit)
    return tracks if explicit.blank?
    
    explicit == 'true' ? tracks.explicit : tracks.where(explicit: false)
  end

  def apply_popularity_filter(tracks, min_popularity)
    return tracks if min_popularity.blank?
    
    tracks.where('spotify_tracks.popularity >= ?', min_popularity.to_i)
  end

  def apply_duplicate_artists_filter(tracks)
    # Use a subquery for better performance
    artist_ids = SpotifyArtist
      .joins(spotify_tracks: { spotify_playlist_tracks: :spotify_playlist })
      .where(spotify_playlists: { mixtape: true })
      .group('spotify_artists.id')
      .having(Arel.sql('COUNT(DISTINCT spotify_tracks.id) > 1'))
      .select(:id)
    
    tracks.joins(:spotify_artists)
          .where(spotify_artists: { id: artist_ids })
  end

  def apply_duplicate_tracks_filter(tracks)
    # Use a subquery for better performance
    duplicate_track_ids = SpotifyPlaylistTrack
      .joins(:spotify_playlist)
      .where(spotify_playlists: { mixtape: true })
      .group(:spotify_track_id)
      .having(Arel.sql('COUNT(DISTINCT spotify_playlist_id) > 1'))
      .select(:spotify_track_id)
    
    tracks.where(id: duplicate_track_ids)
  end

  def build_track_display_info
    # Batch load all the display info
    track_ids = @tracks.map(&:id)
    
    track_playlist_data = SpotifyPlaylistTrack
      .joins(:spotify_playlist)
      .where(
        spotify_track_id: track_ids,
        spotify_playlists: { mixtape: true }
      )
      .select(
        'spotify_playlist_tracks.spotify_track_id',
        'spotify_playlist_tracks.position',
        'spotify_playlist_tracks.spotify_playlist_id',
        'spotify_playlists.made_on',
        'spotify_playlists.made_by'
      )
      .includes(:spotify_playlist)
    
    # Group by track_id for easy access
    grouped_info = track_playlist_data.group_by(&:spotify_track_id)
    
    @track_display_info = {}
    @tracks.each do |track|
      playlist_tracks = grouped_info[track.id] || []
      
      if playlist_tracks.any?
        # Sort by date to get the most recent
        sorted_by_date = playlist_tracks.sort_by { |pt| pt.made_on || Date.new(1900,1,1) }.reverse
        most_recent = sorted_by_date.first
        
        @track_display_info[track.id] = {
          position: most_recent.position,
          primary_playlist: most_recent.spotify_playlist,
          made_by: most_recent.made_by,
          all_playlists: playlist_tracks.map(&:spotify_playlist).uniq
        }
      end
    end
  end

end