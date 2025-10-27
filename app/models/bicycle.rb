class Bicycle < ApplicationRecord
  # Associations
  has_many :rides, dependent: :destroy
  has_many :milestones, dependent: :destroy
  has_many :strava_activities, through: :rides
  
  # Validations
  validates :name, presence: true, uniqueness: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :with_strava, -> { where.not(strava_gear_id: nil) }
  scope :alphabetical, -> { order(:name) }
  scope :by_most_recent_ride, -> {
    left_joins(:rides)
      .group('bicycles.id')
      .order(Arel.sql('MAX(rides.rode_on) DESC NULLS LAST'))
  }
  
  # Calculate total miles for this bicycle
  def total_miles
    rides.sum(:miles) || 0
  end
  
  # Calculate miles between dates
  def miles_between(start_date, end_date = Date.current)
    rides.where(rode_on: start_date..end_date).sum(:miles) || 0
  end
  
  # Calculate miles since a specific milestone
  def miles_since_milestone(milestone)
    return 0 unless milestone.bicycle_id == id
    
    rides.where('rode_on >= ?', milestone.occurred_on).sum(:miles) || 0
  end
  
  # Calculate total time ridden (in seconds)
  def total_duration
    rides.sum(:duration) || 0
  end
  
  # Get the most recent ride
  def most_recent_ride
    rides.order(rode_on: :desc).first
  end
  
  # Get the most recent milestone
  def most_recent_milestone
    milestones.order(occurred_on: :desc).first
  end
  
  # Format total duration as human readable
  def total_duration_formatted
    return "0:00" if total_duration.zero?
    
    total_seconds = total_duration
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    
    if hours > 0
      format("%d:%02d", hours, minutes)
    else
      format("%d:%02d", minutes / 60, minutes % 60)
    end
  end
  
  # Get average speed (mph)
  def average_speed
    return 0 if total_duration.zero? || total_miles.zero?
    
    hours = total_duration / 3600.0
    (total_miles / hours).round(1)
  end
  
  # Check if this bike has any Strava data
  def has_strava_data?
    strava_gear_id.present?
  end
  
  # Get ride count
  def ride_count
    rides.count
  end
  
  # Get milestone count
  def milestone_count
    milestones.count
  end
end
