class ScrobblePlay < ApplicationRecord
  belongs_to :scrobble_artist
  belongs_to :scrobble_album

  scope :artists, -> { where(category: 'artist') }
  scope :albums, -> { where(category: 'album') }
  scope :by_category, ->(category) { where(category: category) }

end
