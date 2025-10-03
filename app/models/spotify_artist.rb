class SpotifyArtist < ApplicationRecord
  # Associations
  has_many :spotify_track_artists, dependent: :destroy
  has_many :spotify_tracks, through: :spotify_track_artists
  
  # Validations
  validates :spotify_id, presence: true, uniqueness: true
  validates :name, presence: true
  
  # Scopes
  scope :popular, -> { where('popularity > ?', 70) }
  scope :by_genre, ->(genre) { where('genres @> ?', [genre].to_json) }
  scope :alphabetical, -> { order(:sort_name) }
  
  # Orphan management scopes
  scope :orphaned, -> {
    left_joins(:spotify_track_artists)
    .where(spotify_track_artists: { id: nil })
  }

  scope :with_tracks, -> {
    joins(:spotify_track_artists).distinct
  }

  scope :on_single_track, -> {
    joins(:spotify_track_artists)
    .group('spotify_artists.id')
    .having('COUNT(DISTINCT spotify_track_artists.spotify_track_id) = 1')
  }

  scope :on_multiple_tracks, -> {
    joins(:spotify_track_artists)
    .group('spotify_artists.id')
    .having('COUNT(DISTINCT spotify_track_artists.spotify_track_id) > 1')
  }

  # Callbacks
  before_save :generate_sort_name
  
  def track_count
    spotify_tracks.count
  end
  
  def playlist_count
    SpotifyPlaylist.joins(spotify_tracks: :spotify_artists)
                   .where(spotify_artists: { id: id })
                   .distinct
                   .count
  end
  
  def genre_list
    genres.is_a?(Array) ? genres.join(', ') : ''
  end
  
  def orphaned?
    spotify_track_artists.empty?
  end

  def on_single_track?
    track_count == 1
  end

  def on_multiple_tracks?
    track_count > 1
  end

  def playlists
    SpotifyPlaylist.joins(spotify_tracks: :spotify_artists)
                   .where(spotify_artists: { id: id })
                   .distinct
  end


  private
  
  def generate_sort_name
    return unless name.present?
    
    text = name.downcase
    text = text.gsub(/^the\s+/, '')
    self.sort_name = text
  end
end