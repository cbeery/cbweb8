class SpotifyTrack < ApplicationRecord
  # Associations
  has_many :spotify_playlist_tracks, dependent: :destroy
  has_many :spotify_playlists, through: :spotify_playlist_tracks
  has_many :spotify_track_artists, dependent: :destroy
  has_many :spotify_artists, through: :spotify_track_artists
  
  # Validations
  validates :spotify_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :duration_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes
  scope :popular, -> { where('popularity > ?', 70) }
  scope :explicit, -> { where(explicit: true) }
  scope :by_artist, ->(artist) { where('artist_text ILIKE ?', "%#{artist}%") }
  scope :by_album, ->(album) { where(album: album) }
  scope :longest_first, -> { order(duration_ms: :desc) }
  scope :most_popular, -> { order(popularity: :desc) }

  # Orphan management scopes
  scope :orphaned, -> { 
    left_joins(:spotify_playlist_tracks)
    .where(spotify_playlist_tracks: { id: nil }) 
  }

  scope :on_playlists, -> {
    joins(:spotify_playlist_tracks).distinct
  }

  scope :on_single_playlist, -> {
    joins(:spotify_playlist_tracks)
    .group('spotify_tracks.id')
    .having('COUNT(DISTINCT spotify_playlist_tracks.spotify_playlist_id) = 1')
  }

  scope :on_multiple_playlists, -> {
    joins(:spotify_playlist_tracks)
    .group('spotify_tracks.id')
    .having('COUNT(DISTINCT spotify_playlist_tracks.spotify_playlist_id) > 1')
  }

  
  # Callbacks
  before_save :generate_artist_text
  before_save :generate_sort_text
  
  def duration_formatted
    return "0:00" if duration_ms.nil? || duration_ms.zero?
    
    total_seconds = duration_ms / 1000
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    format("%d:%02d", minutes, seconds)
  end
  
  def primary_artist
    spotify_artists.joins(:spotify_track_artists)
                   .where(spotify_track_artists: { position: 0 })
                   .first
  end
  
  def featured_artists
    spotify_artists.joins(:spotify_track_artists)
                   .where('spotify_track_artists.position > 0')
                   .order('spotify_track_artists.position')
  end
  
  # Audio features helpers (if stored)
  def energy
    audio_features&.dig('energy')
  end
  
  def danceability
    audio_features&.dig('danceability')
  end
  
  def valence
    audio_features&.dig('valence')
  end
  
  def tempo
    audio_features&.dig('tempo')
  end
  
  def orphaned?
    spotify_playlist_tracks.empty?
  end

  def playlist_count
    spotify_playlists.count
  end

  def on_single_playlist?
    playlist_count == 1
  end

  def on_multiple_playlists?
    playlist_count > 1
  end

  private
  
  def generate_artist_text
    if spotify_artists.any?
      self.artist_text = spotify_artists.order('spotify_track_artists.position').pluck(:name).join(', ')
    end
  end
  
  def generate_sort_text
    return unless artist_text.present?
    
    text = artist_text.downcase
    text = text.gsub(/^the\s+/, '')
    self.artist_sort_text = text
  end
end
