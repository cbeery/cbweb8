class ConcertPerformance < ApplicationRecord
  belongs_to :concert
  belongs_to :concert_artist
  
  validates :concert_artist_id, uniqueness: { scope: :concert_id }
  
  acts_as_list scope: :concert
  
  delegate :name, to: :concert_artist, prefix: true, allow_nil: true
end