# app/models/theater.rb
class Theater < ApplicationRecord
  # Associations
  has_many :viewings
  has_many :movies, -> { distinct }, through: :viewings
  
  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:city, :state], case_sensitive: false, 
                                message: "already exists in this location" }
  
  # Scopes
  scope :alphabetical, -> { order(:name) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_state, ->(state) { where(state: state) }
  scope :active, -> { joins(:viewings).distinct }
  scope :with_recent_viewings, -> { includes(:viewings).where(viewings: { viewed_on: 30.days.ago.. }) }
  
  # Class methods for form selects
  def self.for_select
    alphabetical.map { |t| [t.display_name, t.id] }
  end
  
  def self.grouped_for_select
    # Group by state for better organization if many theaters
    if count > 20
      order(:state, :city, :name).group_by(&:state).map do |state, theaters|
        [state || 'Unknown', theaters.map { |t| [t.display_name_short, t.id] }]
      end
    else
      for_select
    end
  end
  
  # Instance methods
  def display_name
    parts = [name]
    parts << city if city.present?
    parts << state if state.present? && city.blank?
    parts.join(', ')
  end
  
  def display_name_short
    # Shorter version for dropdowns
    city.present? ? "#{name} (#{city})" : name
  end
  
  def location
    return nil if city.blank? && state.blank?
    [city, state].compact.join(', ')
  end
  
  def full_address
    [address, city, state].compact.join(', ')
  end
  
  def viewing_count
    viewings.count
  end
  
  def movie_count
    movies.count
  end
  
  def last_visited
    viewings.maximum(:viewed_on)
  end
  
  def average_price
    viewings.where.not(price: nil).average(:price)
  end
  
  def favorite_format
    viewings.where.not(format: nil)
            .group(:format)
            .count
            .max_by { |_format, count| count }
            &.first
  end
  
  # Check if recently visited
  def recently_visited?(days = 30)
    last_visited && last_visited > days.days.ago
  end
end
