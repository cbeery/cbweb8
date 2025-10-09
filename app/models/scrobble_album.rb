class ScrobbleAlbum < ApplicationRecord
  belongs_to :scrobble_artist
  has_many :scrobble_plays
end
