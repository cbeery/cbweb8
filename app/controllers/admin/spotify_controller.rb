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
  
  def mixtapes
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
                          .includes(:spotify_artists, :spotify_playlists)
    
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
    
    if params[:artist].present?
      @tracks = @tracks.by_artist(params[:artist])
    end
    
    if params[:explicit].present?
      @tracks = params[:explicit] == 'true' ? @tracks.explicit : @tracks.where(explicit: false)
    end
    
    if params[:min_popularity].present?
      @tracks = @tracks.where('popularity >= ?', params[:min_popularity].to_i)
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
    
    @tracks = @tracks.page(params[:page]).per(50)
    
    # Get filter options
    @available_years = SpotifyPlaylist.mixtapes.distinct.pluck(:year).compact.sort.reverse
    @available_months = (1..12).map { |m| [Date::MONTHNAMES[m], m] }
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
  
  private
  
  def set_playlist
    @playlist = SpotifyPlaylist.find(params[:id])
  end
  
  def playlist_params
    params.require(:spotify_playlist).permit(:name, :spotify_url, :made_by, :mixtape, :made_on)
  end
end