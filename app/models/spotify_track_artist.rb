class SpotifyTrackArtist < ApplicationRecord
  belongs_to :spotify_track
  belongs_to :spotify_artist
end
