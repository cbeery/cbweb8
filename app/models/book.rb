# app/models/book.rb (additions/changes)
class Book < ApplicationRecord
  # Associations
  has_many :book_reads, dependent: :destroy
  has_one :current_read, -> { in_progress }, class_name: 'BookRead'
  has_one :most_recent_read, -> { completed.recent }, class_name: 'BookRead'
  has_one_attached :cover_image
  
  # Enums
  enum :status, {
    want_to_read: 0,
    currently_reading: 1,
    read: 2
  }, default: :want_to_read
  
  # Validations
  validates :title, presence: true
  validates :author, presence: true
  validates :hardcover_id, uniqueness: { allow_blank: true }
  validates :goodreads_id, uniqueness: { allow_blank: true }
  validates :rating, numericality: { in: 0..5, allow_nil: true }
  validates :progress, numericality: { in: 0..100, allow_nil: true }
  
  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :with_reads, -> { includes(:book_reads) }
  scope :read_in_year, ->(year) {
    joins(:book_reads)
      .where('EXTRACT(YEAR FROM book_reads.finished_on) = ?', year)
      .distinct
  }
  scope :recently_read, -> {
    joins(:book_reads)
      .where.not(book_reads: { finished_on: nil })
      .order('book_reads.finished_on DESC')
      .distinct
  }
  
  # Get the most recent started_on date (for compatibility)
  def started_on
    current_read&.started_on || most_recent_read&.started_on
  end
  
  # Get the most recent finished_on date (for compatibility)
  def finished_on
    most_recent_read&.finished_on
  end

  # For display in views
  def display_status
    status.humanize
  end

  # For series display
  def full_series_name
    return nil unless series.present?
    series_position.present? ? "#{series} ##{series_position}" : series
  end
  
  # Get all reading dates
  def reading_dates
    book_reads.pluck(:started_on, :finished_on).map do |started, finished|
      { started_on: started, finished_on: finished }
    end
  end
  
  # Check if should sync cover
  def should_sync_cover?
    !cover_manually_uploaded? && !cover_image.attached?
  end
  
  # Calculate average rating across all reads
  def average_rating
    completed_reads = book_reads.completed.where.not(rating: nil)
    return nil if completed_reads.empty?
    
    completed_reads.average(:rating).round(1)
  end
  
  # Get reading history summary
  def reading_summary
    reads = book_reads.completed.recent
    
    if reads.empty?
      "Not yet read"
    elsif reads.count == 1
      read = reads.first
      "Read once (#{read.finished_on&.year || 'date unknown'})"
    else
      years = reads.map { |r| r.finished_on&.year }.compact.uniq.sort
      "Read #{reads.count} times (#{years.join(', ')})"
    end
  end
  
  # Find or create a read for syncing
  def find_or_create_read_for_sync(started_on: nil, finished_on: nil)
    # If currently reading, return the current read
    if status == 'currently_reading' && current_read
      current_read
    # If we have dates, try to find a matching read
    elsif finished_on.present?
      book_reads.find_or_initialize_by(finished_on: finished_on)
    elsif started_on.present?
      book_reads.find_or_initialize_by(started_on: started_on, finished_on: nil)
    else
      # No dates, create a basic read entry
      book_reads.build
    end
  end
end
