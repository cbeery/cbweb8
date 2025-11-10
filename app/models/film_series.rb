class FilmSeries < ApplicationRecord
  has_many :film_series_events, -> { order('started_on DESC')}, dependent: :destroy
  has_many :viewings, -> { order('viewed_on DESC')}, through: :film_series_events
end
