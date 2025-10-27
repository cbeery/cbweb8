class Milestone < ApplicationRecord
  # Associations
  belongs_to :bicycle
  
  # Validations
  validates :bicycle_id, presence: true
  validates :occurred_on, presence: true
  validates :title, presence: true
  
  # Scopes
  scope :recent, -> { order(occurred_on: :desc) }
  scope :oldest_first, -> { order(occurred_on: :asc) }
  scope :by_bike, ->(bike_id) { where(bicycle_id: bike_id) if bike_id.present? }
  scope :by_year, ->(year) { 
    where('EXTRACT(YEAR FROM occurred_on) = ?', year) if year.present? 
  }
  scope :before, ->(date) { where('occurred_on <= ?', date) }
  scope :after, ->(date) { where('occurred_on >= ?', date) }
  scope :between, ->(start_date, end_date) { where(occurred_on: start_date..end_date) }
  
  # Calculate miles since this milestone
  def miles_since
    bicycle.rides.since(occurred_on).sum(:miles) || 0
  end
  
  # Calculate rides since this milestone
  def rides_since
    bicycle.rides.since(occurred_on).count
  end
  
  # Calculate days since this milestone
  def days_since
    (Date.current - occurred_on).to_i
  end
  
  # Get the next milestone after this one
  def next_milestone
    bicycle.milestones.where('occurred_on > ?', occurred_on).oldest_first.first
  end
  
  # Get the previous milestone before this one
  def previous_milestone
    bicycle.milestones.where('occurred_on < ?', occurred_on).recent.first
  end
  
  # Calculate miles between this milestone and another (or current date)
  def miles_until(end_milestone_or_date = Date.current)
    end_date = case end_milestone_or_date
    when Milestone
      end_milestone_or_date.occurred_on
    when Date, Time, DateTime
      end_milestone_or_date.to_date
    else
      Date.current
    end
    
    bicycle.miles_between(occurred_on, end_date)
  end
  
  # Get a summary of activity since this milestone
  def activity_summary
    rides = bicycle.rides.since(occurred_on)
    total_miles = rides.sum(:miles) || 0
    total_duration = rides.sum(:duration) || 0
    ride_count = rides.count
    
    {
      miles: total_miles,
      rides: ride_count,
      duration: total_duration,
      days_elapsed: days_since,
      average_miles_per_ride: ride_count > 0 ? (total_miles / ride_count.to_f).round(1) : 0,
      average_miles_per_week: days_since > 0 ? (total_miles / (days_since / 7.0)).round(1) : 0
    }
  end
  
  # Format occurred_on for display
  def occurred_on_formatted
    occurred_on.strftime("%B %d, %Y") if occurred_on.present?
  end
  
  # Check if this is a maintenance milestone (based on keywords in title/description)
  def maintenance?
    maintenance_keywords = ['tire', 'chain', 'brake', 'service', 'tune', 'repair', 'replace', 'oil', 'clean']
    text_to_check = "#{title} #{description}".downcase
    
    maintenance_keywords.any? { |keyword| text_to_check.include?(keyword) }
  end
  
  # Get year of the milestone
  def year
    occurred_on.year if occurred_on.present?
  end
  
  # Get month of the milestone
  def month
    occurred_on.month if occurred_on.present?
  end
end
