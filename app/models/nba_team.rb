class NbaTeam < ApplicationRecord
  # Associations
  has_many :home_games, class_name: 'NbaGame', foreign_key: 'home_id', dependent: :destroy
  has_many :away_games, class_name: 'NbaGame', foreign_key: 'away_id', dependent: :destroy
  has_one_attached :logo
  
  # Validations
  validates :name, :abbreviation, :city, presence: true
  validates :abbreviation, uniqueness: true, length: { is: 3 }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_conference, ->(conf) { where(conference: conf) }
  scope :alphabetical, -> { order(:city, :name) }
  
  # Instance methods
  def games
    NbaGame.where('home_id = ? OR away_id = ?', id, id)
  end
  
  def display_name
    "#{city} #{name}"
  end
  
  def games_watched
    games.watched
  end
  
  def playoff_games
    games.where(postseason: true)
  end
  
  def regular_season_games
    games.where(preseason: false, postseason: false)
  end
  
  def total_quarters_watched
    games.sum(:quarters_watched)
  end
  
  def watched_percentage
    total_games = games.count
    return 0 if total_games.zero?
    
    watched_games = games.watched.count
    (watched_games.to_f / total_games * 100).round(1)
  end
  
  def logo_url
    return nil unless logo.attached?
    Rails.application.routes.url_helpers.rails_blob_url(logo, only_path: true)
  end
end
