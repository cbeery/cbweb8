class Viewing < ApplicationRecord
  belongs_to :movie
  belongs_to :theater, optional: true
  belongs_to :film_series_event, optional: true  
  # Validations
  validates :viewed_on, presence: true
  
  # Scopes
  scope :rewatches, -> { where(rewatch: true) }
  scope :first_watches, -> { where(rewatch: false) }
  scope :recent, -> { order(viewed_on: :desc) }
  scope :chronological, -> { order(viewed_on: :asc) }
  scope :this_year, -> { where(viewed_on: Date.current.beginning_of_year..Date.current.end_of_year) }
  scope :by_year, ->(year) { where(viewed_on: Date.new(year, 1, 1)..Date.new(year, 12, 31)) }
  
  # Callbacks
  before_validation :set_rewatch_status
  
  private
  
  def set_rewatch_status
    return if rewatch.present?
    return unless movie && viewed_on
    
    self.rewatch = movie.viewings.where('viewed_on < ?', viewed_on).exists?
  end
end