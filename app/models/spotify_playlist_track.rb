class SpotifyPlaylistTrack < ApplicationRecord
  belongs_to :spotify_playlist
  belongs_to :spotify_track
end
