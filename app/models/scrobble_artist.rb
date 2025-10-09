class ScrobbleArtist < ApplicationRecord
  has_many :scrobble_albums
  has_many :scrobble_plays
end
