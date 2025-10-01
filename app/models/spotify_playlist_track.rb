class SpotifyPlaylistTrack < ApplicationRecord
  belongs_to :spotify_playlist
  belongs_to :spotify_track
  
  # Validations
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :spotify_track_id, uniqueness: { scope: :spotify_playlist_id }
  
  # Scopes
  scope :ordered, -> { order(:position) }
end