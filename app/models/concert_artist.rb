class ConcertArtist < ApplicationRecord
  has_many :concert_performances, dependent: :destroy
  has_many :concerts, through: :concert_performances
  
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  
  scope :alphabetical, -> { order(:name) }
  scope :by_concert_count, -> {
    left_joins(:concert_performances)
      .group(:id)
      .order('COUNT(concert_performances.id) DESC')
  }
  
  before_validation :normalize_name
  
  private
  
  def normalize_name
    self.name = name&.strip&.titleize
  end
end