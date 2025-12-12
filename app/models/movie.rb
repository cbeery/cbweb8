# app/models/movie.rb
class Movie < ApplicationRecord
  # Associations
  has_many :viewings, dependent: :destroy
  has_one :movie_poster, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :rating, inclusion: { in: 0.5..5.0 }, allow_nil: true
  validates :score, inclusion: { in: 0..100 }, allow_nil: true
  validates :letterboxd_id, uniqueness: true, allow_nil: true

  # Scopes
  scope :by_year, ->(year) { where(year: year) }
  scope :highly_rated, -> { where('rating >= ?', 4.0) }
  scope :recent, -> { order(created_at: :desc) }
  scope :alphabetical, -> { order(title: :asc) }

  # Callbacks
  before_validation :normalize_rating

  # Convenience alias for backward compatibility during transition
  alias_method :primary_poster, :movie_poster

  def watched?
    viewings.exists?
  end

  def watch_count
    viewings.count
  end

  def first_watched
    viewings.minimum(:viewed_on)
  end

  def last_watched
    viewings.maximum(:viewed_on)
  end

  private

  def normalize_rating
    return unless rating
    self.rating = rating.round(1) # Ensure it's to 0.5 increments
    self.rating = [[rating, 0.5].max, 5.0].min # Clamp between 0.5 and 5.0
  end
end
