class Concert < ApplicationRecord
  belongs_to :concert_venue
  has_many :concert_performances, -> { order(:position) }, dependent: :destroy
  has_many :concert_artists, through: :concert_performances
  
  validates :played_on, presence: true
  
  scope :recent, -> { order(played_on: :desc) }
  scope :upcoming, -> { where('played_on >= ?', Date.current).order(played_on: :asc) }
  scope :past, -> { where('played_on < ?', Date.current).order(played_on: :desc) }
  
  accepts_nested_attributes_for :concert_performances, allow_destroy: true, reject_if: :all_blank
  
  def display_name
    "#{concert_artists.pluck(:name).join(', ')} at #{concert_venue.name} (#{played_on&.strftime('%b %d, %Y')})"
  end
end