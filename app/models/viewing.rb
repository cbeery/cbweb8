# app/models/viewing.rb
class Viewing < ApplicationRecord

  VALID_LOCATIONS = %w[home theater airplane streaming netflix appletv hulu hbo disney amazon peacock hoopla kanopy other].freeze

  # Associations
  belongs_to :movie
  belongs_to :theater, optional: true
  belongs_to :film_series_event, optional: true
  
  # Validations
  validates :viewed_on, presence: true
  validates :location, inclusion: { in: VALID_LOCATIONS }, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes
  scope :rewatches, -> { where(rewatch: true) }
  scope :first_watches, -> { where(rewatch: false) }
  scope :recent, -> { order(viewed_on: :desc) }
  scope :chronological, -> { order(viewed_on: :asc) }
  scope :this_year, -> { where(viewed_on: Date.current.beginning_of_year..Date.current.end_of_year) }
  scope :by_year, ->(year) { where(viewed_on: Date.new(year, 1, 1)..Date.new(year, 12, 31)) }
  scope :at_home, -> { where(location: 'home') }
  scope :in_theater, -> { where(location: 'theater') }
  scope :with_theater, -> { where.not(theater_id: nil) }
  scope :with_film_series, -> { joins(:film_series_event) }
  
  # Callbacks
  before_validation :set_defaults  # NEW: Added this to ensure viewed_on is set
  before_validation :set_rewatch_status
  # before_validation :set_viewed_at_from_viewed_on
  
  # Class methods
  def self.total_spent
    sum(:price)
  end
  
  def self.average_price
    where.not(price: nil).average(:price)
  end
  
  # NEW: Add helper methods for forms (optional but helpful)
  def self.location_options
    [
      ['Home', 'home'],
      ['Theater', 'theater'],
      ['Airplane', 'airplane'],
      ['Streaming', 'streaming'],
      ['Netflix', 'netflix'],
      ['Apple TV+', 'appletv'],
      ['Hulu', 'hulu'],
      ['HBO / Max', 'hbo'],
      ['Disney+', 'disney'],
      ['Amazon Prime', 'amazon'],
      ['Peacock', 'peacock'],
      ['Hoopla', 'hoopla'],
      ['Kanopy', 'kanopy'],
      ['Other', 'other']
    ]
  end

  def self.format_options
    [
      ['Standard', 'standard'],
      ['IMAX', 'imax'],
      ['Dolby', 'dolby'],
      ['3D', '3d'],
      ['70mm', '70mm'],
      ['35mm', '35mm']
    ]
  end
  
  # Instance methods
  def display_location
    if theater.present?
      "#{theater.name}#{theater.city.present? ? " (#{theater.city})" : ''}"
    elsif location.present?
      location.capitalize
    else
      "Unknown"
    end
  end
  
  def film_series
    film_series_event&.film_series
  end
  
  # NEW: Add helper methods for checking location type
  def theater_viewing?
    location == 'theater'
  end
  
  def home_viewing?
    location == 'home'
  end
  
  def display_date
    viewed_on&.strftime('%B %d, %Y')
  end
  
  def display_format
    format&.upcase || 'Standard'
  end
  
  private
  
  # NEW: Add set_defaults method to ensure viewed_on and location have defaults
  def set_defaults
    # Ensure viewed_on has a default if not set
    self.viewed_on ||= Date.current if new_record?
    
    # Set default location if not specified
    self.location ||= 'home' if new_record? && location.blank?
    
    # Clear theater-related fields if not a theater viewing
    unless theater_viewing?
      self.theater_id = nil
      self.price = nil
      self.format = nil
    end
  end
  
  def set_rewatch_status
    # Only auto-set if rewatch is nil and we have the required data
    return unless rewatch.nil? && movie && viewed_on
    
    # Check if this movie was viewed before this date
    self.rewatch = movie.viewings
                        .where.not(id: id) # Exclude self if updating
                        .where('viewed_on < ?', viewed_on)
                        .exists?
  end
  
  def set_viewed_at_from_viewed_on
    # TODO - Update this to use Chronig and time field
    # If we have a specific datetime, use it
    # Otherwise, set a default evening time for the viewing
    if viewed_at.blank? && viewed_on.present?
      # Default to 8 PM on the viewing date
      self.viewed_at = viewed_on.to_datetime + 20.hours
    end
  end
end
