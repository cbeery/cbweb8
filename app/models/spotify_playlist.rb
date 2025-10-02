class SpotifyPlaylist < ApplicationRecord
  # Associations
  has_many :spotify_playlist_tracks, dependent: :destroy
  has_many :spotify_tracks, through: :spotify_playlist_tracks
  has_many :log_entries, as: :loggable, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :spotify_url, presence: true, uniqueness: true
  validates :spotify_url, format: { 
    with: /\Ahttps:\/\/(open\.)?spotify\.com\/(user\/[\w-]+\/)?playlist\/[\w]+/,
    message: "must be a valid Spotify playlist URL" 
  }
  
  # Scopes
  scope :mixtapes, -> { where(mixtape: true) }
  scope :non_mixtapes, -> { where(mixtape: false) }
  scope :by_year, ->(year) { where(year: year) }
  scope :by_month, ->(month) { where(month: month) }
  scope :recent, -> { order(made_on: :desc) }
  scope :needs_sync, -> { where('last_synced_at IS NULL OR last_synced_at < ?', 24.hours.ago) }
  
  # Callbacks
  before_save :extract_spotify_id
  before_save :extract_date_parts
  before_save :normalize_url
  # after_save :queue_sync_if_new
  
  # Calculate runtime from tracks
  def calculate_runtime!
    total_ms = spotify_tracks.sum(:duration_ms)
    update_column(:runtime_ms, total_ms)
  end
  
  def runtime_formatted
    return "0:00" if runtime_ms.nil? || runtime_ms.zero?
    
    total_seconds = runtime_ms / 1000
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    seconds = total_seconds % 60
    
    if hours > 0
      format("%d:%02d:%02d", hours, minutes, seconds)
    else
      format("%d:%02d", minutes, seconds)
    end
  end
  
  def track_count
    spotify_playlist_tracks.count
  end
  
  def needs_sync?
    last_synced_at.nil? || last_synced_at < 24.hours.ago
  end
  
  # Check if playlist has been modified since last sync
  def modified_since_last_sync?
    return false if snapshot_id.blank? || previous_snapshot_id.blank?
    snapshot_id != previous_snapshot_id
  end
  
  # Get human-readable last modified text
  def last_modified_text
    return "Unknown" if last_modified_at.nil?
    last_modified_at
  end
  
  # Get the most recently added track
  def most_recent_track_addition
    spotify_playlist_tracks.where.not(added_at: nil).maximum(:added_at)
  end
  
  # Check if playlist content is stale
  def content_stale?
    return true if last_modified_at.nil?
    last_modified_at < 30.days.ago
  end

  private
  
  def extract_spotify_id
    return unless spotify_url.present?
    
    if match = spotify_url.match(/playlist\/([\w]+)/)
      self.spotify_id = match[1]
    end
  end
  
  def extract_date_parts
    return unless made_on.present?
    
    self.year = made_on.year
    self.month = made_on.month
  end
  
  def normalize_url
    return unless spotify_url.present?
    
    # Replace spotify.com with open.spotify.com, but not if "open." is already there
    self.spotify_url = spotify_url.gsub(/(?<!open\.)spotify\.com/, 'open.spotify.com')
    
    # Remove any query parameters
    self.spotify_url = spotify_url.split('?').first
  end

  def queue_sync_if_new
    if saved_change_to_spotify_url? || (id_previously_changed? && spotify_id.present?)
      Rails.logger.info "Queueing initial sync for playlist #{id}"
      # Only queue if we have the sync service
      SyncJob.perform_later('Sync::SpotifyService', nil, broadcast: false) if defined?(Sync::SpotifyService)
    end
  end
end
