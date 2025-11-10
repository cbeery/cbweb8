class Ride < ApplicationRecord
  # Associations
  belongs_to :bicycle
  belongs_to :strava_activity, optional: true
  
  # Validations
  validates :bicycle_id, presence: true
  validates :rode_on, presence: true
  validates :miles, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Virtual attribute for duration input (like "1:30:45" or "45:30")
  attr_accessor :duration_input
  
  # Callbacks
  before_save :parse_duration_input
  after_save :update_strava_association
  
  # Scopes
  scope :recent, -> { order(rode_on: :desc) }
  scope :oldest_first, -> { order(rode_on: :asc) }
  scope :by_year, ->(year) { 
    where('EXTRACT(YEAR FROM rode_on) = ?', year) if year.present? 
  }
  scope :by_month, ->(month, year = Date.current.year) {
    where('EXTRACT(MONTH FROM rode_on) = ? AND EXTRACT(YEAR FROM rode_on) = ?', month, year)
  }
  scope :by_bike, ->(bike_id) { where(bicycle_id: bike_id) if bike_id.present? }
  scope :with_strava, -> { where.not(strava_activity_id: nil) }
  scope :without_strava, -> { where(strava_activity_id: nil) }
  scope :since, ->(date) { where('rode_on >= ?', date) }
  scope :before, ->(date) { where('rode_on <= ?', date) }
  scope :between, ->(start_date, end_date) { where(rode_on: start_date..end_date) }
  scope :longest_first, -> { order(miles: :desc) }
  scope :shortest_first, -> { order(miles: :asc) }
  
  # Format duration as HH:MM:SS or MM:SS
  def duration_formatted
    return "0:00" if duration.nil? || duration.zero?
    
    hours = duration / 3600
    minutes = (duration % 3600) / 60
    seconds = duration % 60
    
    if hours > 0
      format("%d:%02d:%02d", hours, minutes, seconds)
    else
      format("%d:%02d", minutes, seconds)
    end
  end
  
  # Calculate average speed (mph)
  def average_speed
    return 0 if duration.nil? || duration.zero? || miles.nil? || miles.zero?
    
    hours = duration / 3600.0
    (miles / hours).round(1)
  end
  
  # Check if this ride is from Strava
  def from_strava?
    strava_activity_id.present?
  end
  
  # Get a summary string
  def summary
    parts = []
    parts << "#{miles} miles" if miles.present?
    parts << duration_formatted if duration.present?
    parts << "@ #{average_speed} mph" if average_speed > 0
    parts.join(' - ')
  end
  
  # Get the year of the ride
  def year
    rode_on.year if rode_on.present?
  end
  
  # Get the month of the ride
  def month
    rode_on.month if rode_on.present?
  end
  
  # Check if ride happened after a milestone
  def after_milestone?(milestone)
    return false unless milestone.bicycle_id == bicycle_id
    
    rode_on >= milestone.occurred_on
  end
  
  private
  
  def parse_duration_input
    return unless duration_input.present?
    
    # Parse duration strings like "1:30:45" (1 hour, 30 min, 45 sec)
    # or "45:30" (45 min, 30 sec) or "45" (45 seconds)
    parts = duration_input.to_s.strip.split(':').map(&:to_i)
    
    self.duration = case parts.length
    when 3 # HH:MM:SS
      parts[0] * 3600 + parts[1] * 60 + parts[2]
    when 2 # MM:SS
      parts[0] * 60 + parts[1]
    when 1 # SS
      parts[0]
    else
      0
    end
  rescue
    # If parsing fails, try to interpret as a number of seconds
    self.duration = duration_input.to_i
  end
  
  def update_strava_association
    # If this ride has a strava_id but no strava_activity_id, try to link them
    if strava_id.present? && strava_activity_id.nil?
      activity = StravaActivity.find_by(strava_id: strava_id)
      update_column(:strava_activity_id, activity.id) if activity
    end
  end
end
