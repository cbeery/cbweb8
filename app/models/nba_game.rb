class NbaGame < ApplicationRecord
  # Associations (using legacy column names)
  belongs_to :away_team, class_name: 'NbaTeam', foreign_key: 'away_id'
  belongs_to :home_team, class_name: 'NbaTeam', foreign_key: 'home_id'
  
  # Validations
  validates :played_on, presence: true
  validates :quarters_watched, inclusion: { in: 0..4 }
  validates :overtimes, numericality: { greater_than_or_equal_to: 0 }
  validate :teams_must_be_different
  validate :playoff_details_consistency
  
  # Scopes
  scope :on_date, ->(date) { where(played_on: date) }
  scope :watched, -> { where('quarters_watched > 0') }
  scope :fully_watched, -> { where(quarters_watched: 4) }
  scope :overtime_games, -> { where('overtimes > 0') }
  scope :recent, -> { order(played_on: :desc, position: :desc, played_at: :desc) }
  scope :upcoming, -> { where('played_on >= ?', Date.current) }
  scope :past, -> { where('played_on < ?', Date.current) }
  scope :by_season, ->(season) { where(season: season) }
  scope :regular_season, -> { where(preseason: false, postseason: false) }
  scope :playoffs, -> { where(postseason: true) }
  scope :preseason_games, -> { where(preseason: true) }
  scope :ordered, -> { order(:position, :played_at, :id) }
  
  # Callbacks
  before_save :set_position_if_nil
  before_save :infer_playoff_details
  
  # Enums for better playoff tracking
  PLAYOFF_ROUNDS = {
    first_round: 1,
    conference_semifinals: 2,
    conference_finals: 3,
    finals: 4
  }.freeze
  
  # Class methods
  def self.current_season
    today = Date.current
    year = today.year
    # NBA season typically starts in October
    if today.month >= 10
      "#{year}-#{(year + 1).to_s.last(2)}"
    else
      "#{year - 1}-#{year.to_s.last(2)}"
    end
  end
  
  def self.playoff_round_name(round)
    case round
    when 1 then 'First Round'
    when 2 then 'Conference Semifinals'
    when 3 then 'Conference Finals'
    when 4 then 'NBA Finals'
    end
  end
  
  # Instance methods
  def display_name
    "#{away_team.abbreviation} @ #{home_team.abbreviation}"
  end
  
  def display_time
    return gametime if gametime.present?
    return played_at.strftime("%-l:%M %p") if played_at.present?
    nil
  end
  
  def watched?
    quarters_watched > 0
  end
  
  def fully_watched?
    # Account for overtime - if OT game, might watch more than 4 "quarters"
    quarters_watched >= 4
  end
  
  def final?
    away_score.present? && home_score.present?
  end
  
  def score_display
    return nil unless final?
    
    if overtimes > 0
      ot_text = overtimes == 1 ? 'OT' : "#{overtimes}OT"
      "#{away_team.abbreviation} #{away_score}, #{home_team.abbreviation} #{home_score} (#{ot_text})"
    else
      "#{away_team.abbreviation} #{away_score}, #{home_team.abbreviation} #{home_score}"
    end
  end
  
  def winner
    return nil unless final?
    away_score > home_score ? away_team : home_team
  end
  
  def game_type_display
    if postseason
      if playoff_round == 4
        "NBA Finals"
      elsif playoff_conference.present?
        "#{playoff_conference} #{self.class.playoff_round_name(playoff_round)}"
      else
        "Playoffs"
      end
    elsif preseason
      "Preseason"
    else
      "Regular Season"
    end
  end
  
  def playoff_game_display
    return nil unless postseason && playoff_series_game_number.present?
    "Game #{playoff_series_game_number}"
  end
  
  def watch_completion_percentage
    return 0 if quarters_watched.zero?
    
    # If overtime, adjust the calculation
    total_periods = 4 + overtimes
    watched_percentage = (quarters_watched.to_f / total_periods * 100).round
    [watched_percentage, 100].min  # Cap at 100%
  end
  
  private
  
  def teams_must_be_different
    errors.add(:away_id, "can't be the same as home team") if home_id == away_id
  end
  
  def playoff_details_consistency
    if postseason
      if playoff_round.present? && playoff_round < 4 && playoff_conference.blank?
        errors.add(:playoff_conference, "must be present for conference playoff games")
      end
      if playoff_round == 4 && playoff_conference.present?
        errors.add(:playoff_conference, "should be blank for NBA Finals")
      end
    else
      if playoff_round.present? || playoff_conference.present? || playoff_series_game_number.present?
        errors.add(:postseason, "must be true if playoff details are set")
      end
    end
  end
  
  def set_position_if_nil
    return if position.present?
    
    # Auto-set position based on game time for ordering
    if played_at.present?
      hour = played_at.hour
      self.position = case hour
                      when 0..12 then 1  # Morning/afternoon game
                      when 13..18 then 2  # Early evening
                      when 19..21 then 3  # Prime time
                      else 4  # Late night
                      end
    else
      self.position = 2  # Default middle position
    end
  end
  
  def infer_playoff_details
    # If it's May-June and no game type is set, likely playoffs
    if played_on.present? && !preseason && !postseason
      if played_on.month.in?([5, 6])
        # Could add logic here to auto-detect playoffs
      end
    end
  end
end