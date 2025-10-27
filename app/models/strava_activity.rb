class StravaActivity < ApplicationRecord
  # Associations
  has_one :ride, dependent: :destroy
  
  # Validations
  validates :strava_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :started_at, presence: true
  validates :activity_type, presence: true
  validates :distance, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :moving_time, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :elapsed_time, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Callbacks
  before_save :set_ended_at
  before_save :set_distance_in_miles
  
  # Scopes
  scope :rides, -> { where(activity_type: 'Ride') }
  scope :runs, -> { where(activity_type: 'Run') }
  scope :non_commutes, -> { where(commute: false).order(started_at: :desc) }
  scope :commutes, -> { where(commute: true) }
  scope :public_activities, -> { where(private: false) }
  scope :private_activities, -> { where(private: true) }
  scope :recent, -> { order(started_at: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }
  scope :with_gear, -> { where.not(gear_id: nil) }
  scope :created_since, ->(time) { where('created_at >= ?', time) }
  scope :updated_since, ->(time) { where('updated_at >= ?', time) }
  scope :started_between, ->(start_date, end_date) { 
    where(started_at: start_date.beginning_of_day..end_date.end_of_day) 
  }
  scope :by_year, ->(year) { 
    where('EXTRACT(YEAR FROM started_at) = ?', year) if year.present? 
  }
  scope :by_month, ->(month, year = Date.current.year) {
    where('EXTRACT(MONTH FROM started_at) = ? AND EXTRACT(YEAR FROM started_at) = ?', month, year)
  }
  
  # Check if this activity should create/update a ride
  def should_sync_ride?
    activity_type == 'Ride' && gear_id.present?
  end
  
  # Find the associated bicycle by gear_id
  def find_bicycle
    return nil unless gear_id.present?
    
    Bicycle.find_by(strava_gear_id: gear_id)
  end
  
  # Format duration (moving time)
  def duration_formatted
    format_seconds(moving_time)
  end
  
  # Format elapsed time
  def elapsed_time_formatted
    format_seconds(elapsed_time)
  end
  
  # Calculate average speed (mph)
  def average_speed_mph
    return 0 if moving_time.nil? || moving_time.zero? || distance_in_miles.nil?
    
    hours = moving_time / 3600.0
    (distance_in_miles / hours).round(1)
  end
  
  # Get activity date
  def activity_date
    started_at.to_date if started_at.present?
  end
  
  # Check if activity has been modified (for sync purposes)
  def modified_since?(timestamp)
    updated_at > timestamp
  end
  
  # Get formatted location
  def location
    [city, state].compact.join(', ').presence || 'Unknown'
  end
  
  # Duration of activity in hours:minutes
  def duration_in_hours
    return 0 if moving_time.nil? || moving_time.zero?
    
    moving_time / 3600.0
  end
  
  private
  
  def set_ended_at
    return unless started_at.present? && elapsed_time.present?
    
    self.ended_at = started_at + elapsed_time.seconds
  end
  
  def set_distance_in_miles
    return unless distance.present?
    
    # Convert from meters to miles (1 meter = 0.000621371 miles)
    self.distance_in_miles = (distance * 0.000621371).round(2)
  end
  
  def format_seconds(seconds)
    return "0:00" if seconds.nil? || seconds.zero?
    
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    
    if hours > 0
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%d:%02d", minutes, secs)
    end
  end
end
