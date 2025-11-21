# app/models/film_series_event.rb
class FilmSeriesEvent < ApplicationRecord
  # Associations
  belongs_to :film_series
  has_many :viewings, -> { order(viewed_on: :desc) }
  has_many :movies, -> { distinct }, through: :viewings
  
  # Validations
  validates :name, presence: true
  validates :started_on, presence: true
  validate :end_date_after_start_date
  
  # Scopes
  scope :current, -> { where('started_on <= ? AND (ended_on IS NULL OR ended_on >= ?)', Date.current, Date.current) }
  scope :upcoming, -> { where('started_on > ?', Date.current).order(:started_on) }
  scope :past, -> { where('ended_on < ?', Date.current).order(ended_on: :desc) }
  scope :chronological, -> { order(:started_on) }
  scope :recent, -> { order(started_on: :desc) }
  
  # Class methods
  def self.for_select
    includes(:film_series)
      .recent
      .map { |e| [e.display_name, e.id] }
  end
  
  # Instance methods
  def display_name
    parts = [name]
    parts << "(#{date_range})" if started_on.present?
    parts.join(' ')
  end
  
  def date_range
    return nil unless started_on
    
    if ended_on.present?
      if started_on.year == ended_on.year
        if started_on.month == ended_on.month
          "#{started_on.strftime('%b %d')}-#{ended_on.day}, #{started_on.year}"
        else
          "#{started_on.strftime('%b %d')} - #{ended_on.strftime('%b %d')}, #{started_on.year}"
        end
      else
        "#{started_on.strftime('%b %d, %Y')} - #{ended_on.strftime('%b %d, %Y')}"
      end
    else
      started_on.strftime('%b %d, %Y')
    end
  end
  
  def duration_in_days
    return nil unless started_on && ended_on
    (ended_on - started_on).to_i + 1
  end
  
  def is_current?
    started_on <= Date.current && (ended_on.nil? || ended_on >= Date.current)
  end
  
  def is_upcoming?
    started_on > Date.current
  end
  
  def is_past?
    ended_on.present? && ended_on < Date.current
  end
  
  def viewing_count
    viewings.count
  end
  
  def unique_movies_count
    movies.count
  end
  
  private
  
  def end_date_after_start_date
    return unless started_on && ended_on
    
    if ended_on < started_on
      errors.add(:ended_on, "must be after the start date")
    end
  end
end
