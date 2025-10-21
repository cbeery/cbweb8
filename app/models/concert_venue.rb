class ConcertVenue < ApplicationRecord
  has_many :concerts, dependent: :restrict_with_exception
  
  validates :name, presence: true
  
  scope :alphabetical, -> { order(:name) }
  scope :by_location, -> { order(:state, :city, :name) }
  
  def display_name
    parts = [name]
    parts << city if city.present?
    parts << state if state.present?
    parts.join(', ')
  end
  
  def location
    [city, state].select(&:present?).join(', ')
  end
end