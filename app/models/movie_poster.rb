# app/models/movie_poster.rb
class MoviePoster < ApplicationRecord
  belongs_to :movie
  
  # CRITICAL: Use dependent: :purge_later to ensure blob is deleted when record is destroyed
  # This prevents orphaned attachments that can attach to recycled IDs
  has_one_attached :image, dependent: :purge_later

  # Validations
  validate :has_image_or_url

  # Callbacks - download image after create if URL present
  after_create :download_image_from_url, if: :url?

  def display_image_url
    if image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
    else
      url
    end
  end

  # Alias for consistency with old code
  alias_method :display_url, :display_image_url
  
  # Check if poster needs to download its image
  def needs_download?
    url.present? && !image.attached?
  end
  
  # Force re-download (purges existing and downloads fresh)
  def redownload!
    return unless url.present?
    
    # Always purge first to prevent stale attachment issues
    image.purge if image.attached?
    
    DownloadPosterJob.perform_later(self)
  end

  private

  def has_image_or_url
    unless image.attached? || url.present?
      errors.add(:base, "Must have either an image or URL")
    end
  end

  def download_image_from_url
    return unless url.present?
    
    DownloadPosterJob.perform_later(self)
  end
end
