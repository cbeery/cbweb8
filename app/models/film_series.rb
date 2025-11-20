# app/models/film_series.rb
class FilmSeries < ApplicationRecord
  # Associations (keeping existing)
  has_many :film_series_events, -> { order(started_on: :desc) }, dependent: :destroy
  has_many :viewings, through: :film_series_events
  has_many :movies, -> { distinct }, through: :viewings
  
  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  
  # Scopes
  scope :alphabetical, -> { order(:name) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_state, ->(state) { where(state: state) }
  scope :active, -> { joins(:film_series_events).where('film_series_events.ended_on >= ? OR film_series_events.ended_on IS NULL', Date.current).distinct }
  scope :with_events, -> { includes(:film_series_events) }
  scope :with_recent_events, -> { joins(:film_series_events).where('film_series_events.started_on >= ?', 1.year.ago).distinct }
  
  # Class methods
  def self.for_select
    alphabetical.map { |fs| [fs.display_name, fs.id] }
  end
  
  # Instance methods
  def display_name
    parts = [name]
    parts << "(#{location})" if location.present?
    parts.join(' ')
  end
  
  def location
    return nil if city.blank? && state.blank?
    [city, state].compact.join(', ')
  end
  
  def current_event
    film_series_events.where('started_on <= ? AND (ended_on IS NULL OR ended_on >= ?)', 
                             Date.current, Date.current).first
  end
  
  def upcoming_events
    film_series_events.where('started_on > ?', Date.current)
  end
  
  def past_events
    film_series_events.where('ended_on < ?', Date.current).where.not(ended_on: nil)
  end
  
  def total_viewings
    viewings.count
  end
  
  def unique_movies_count
    movies.count
  end
  
  def event_count
    film_series_events.count
  end
  
  def date_range
    return nil if film_series_events.empty?
    
    earliest = film_series_events.minimum(:started_on)
    latest = film_series_events.maximum(:ended_on) || Date.current
    
    "#{earliest.year} - #{latest.year}"
  end
  
  def active?
    current_event.present? || upcoming_events.exists?
  end
end
