# app/models/book.rb
class Book < ApplicationRecord
  # Enums - Rails 8 syntax
  enum :status, {
    want_to_read: 0,
    currently_reading: 1,
    read: 2
  }, default: :want_to_read
  
  # ActiveStorage
  has_one_attached :cover_image
  
  # Validations
  validates :title, presence: true
  validates :author, presence: true
  validates :rating, inclusion: { in: 0.0..5.0 }, allow_nil: true
  validates :progress, inclusion: { in: 0..100 }, allow_nil: true
  validates :hardcover_id, uniqueness: true, allow_nil: true
  
  # Scopes
  scope :finished, -> { where(status: :read) }
  scope :reading, -> { where(status: :currently_reading) }
  scope :want_to_read, -> { where(status: :want_to_read) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :by_finished_date, -> { order(finished_on: :desc) }
  scope :rated, -> { where.not(rating: nil) }
  scope :in_series, -> { where.not(series: nil) }
  
  # Time-based scopes for sync
  scope :finished_in_last, ->(duration) { 
    where(status: :read).where(finished_on: duration.ago..Time.current) 
  }
  
  # Callbacks
  before_validation :normalize_rating
  
  # Methods
  def display_status
    status.humanize
  end
  
  def cover_image_url
    if cover_image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(cover_image, only_path: true)
    end
  end
  
  def should_sync_cover?
    !cover_manually_uploaded? && !cover_image.attached?
  end
  
  def full_series_name
    return nil unless series.present?
    series_position.present? ? "#{series} ##{series_position}" : series
  end
  
  private
  
  def normalize_rating
    return unless rating
    # Round to nearest 0.5
    self.rating = (rating * 2).round / 2.0
    # Clamp between 0.0 and 5.0
    self.rating = [[rating, 0.0].max, 5.0].min
  end
end