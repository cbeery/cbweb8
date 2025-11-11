# app/models/book_read.rb
class BookRead < ApplicationRecord
  belongs_to :book, counter_cache: :times_read
  
  # Validations
  validates :book_id, presence: true
  validates :read_number, uniqueness: { scope: :book_id }, numericality: { greater_than: 0 }
  validate :finished_after_started
  
  # Scopes
  scope :completed, -> { where.not(finished_on: nil) }
  scope :in_progress, -> { where(finished_on: nil).where.not(started_on: nil) }
  scope :recent, -> { order(finished_on: :desc, started_on: :desc) }
  scope :by_year, ->(year) { where('EXTRACT(YEAR FROM finished_on) = ?', year) }
  scope :this_year, -> { by_year(Date.current.year) }
  scope :last_30_days, -> { where('finished_on >= ?', 30.days.ago) }
  
  # Callbacks
  before_validation :set_read_number, on: :create
  after_save :update_book_rating
  after_save :update_book_status
  
  # Calculate duration in days
  def duration_days
    return nil unless started_on && finished_on
    (finished_on - started_on).to_i
  end
  
  # Check if currently reading
  def currently_reading?
    started_on.present? && finished_on.nil?
  end
  
  # Check if completed
  def completed?
    finished_on.present?
  end
  
  # For display
  def display_dates
    if finished_on.present? && started_on.present?
      "#{started_on.strftime('%b %d')} - #{finished_on.strftime('%b %d, %Y')}"
    elsif finished_on.present?
      "Finished: #{finished_on.strftime('%b %d, %Y')}"
    elsif started_on.present?
      "Started: #{started_on.strftime('%b %d, %Y')}"
    else
      "No dates recorded"
    end
  end
  
  private
  
  def finished_after_started
    return unless started_on && finished_on
    
    if finished_on < started_on
      errors.add(:finished_on, "can't be before started date")
    end
  end
  
  def set_read_number
    return if read_number.present?
    
    # Set read_number to the next number for this book
    max_read = book.book_reads.maximum(:read_number) || 0
    self.read_number = max_read + 1
  end
  
  def update_book_rating
    # Update the book's rating to match the most recent completed read
    return unless rating_previously_changed? || finished_on_previously_changed?
    
    most_recent_read = book.book_reads.completed.recent.first
    if most_recent_read
      book.update_column(:rating, most_recent_read.rating)
    end
  end
  
  def update_book_status
    # Update book status based on reads
    if currently_reading?
      book.update_column(:status, 'currently_reading')
    elsif completed? && self == book.book_reads.recent.first
      book.update_column(:status, 'read')
    end
  end
end
