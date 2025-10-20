class ConcertPerformance < ApplicationRecord
  belongs_to :concert
  belongs_to :concert_artist
end
