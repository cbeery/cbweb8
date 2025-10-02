class SpotifyTrackArtist < ApplicationRecord
  belongs_to :spotify_track
  belongs_to :spotify_artist
  
  # Validations
  validates :spotify_artist_id, uniqueness: { scope: :spotify_track_id }
  
  # Scopes
  scope :ordered, -> { order(:position) }
  scope :primary, -> { where(position: 0) }
  scope :featured, -> { where('position > 0') }
end