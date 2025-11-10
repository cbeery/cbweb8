class FilmSeriesEvent < ApplicationRecord
  belongs_to :film_series
  has_many :viewings, -> { order('viewed_on DESC')}
end
