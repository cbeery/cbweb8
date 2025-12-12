# app/models/movie_poster.rb
class MoviePoster < ApplicationRecord
  belongs_to :movie
  has_one_attached :image
  
  # Validations
  validate :has_image_or_url
  
  # Scopes
  scope :primary, -> { where(primary: true) }
  scope :ordered, -> { order(:position, :created_at) }
  
  # Callbacks
  before_validation :set_position, on: :create
  after_create :download_image_from_url, if: :should_download_image?
  after_save :ensure_single_primary
  
  # Returns the best available URL for displaying this poster
  def display_url
    if image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
    else
      url
    end
  end
  
  # Alias for backwards compatibility
  alias_method :display_image_url, :display_url
  
  # Check if we need to download the image
  def needs_download?
    url.present? && !image.attached?
  end
  
  # Manually trigger a re-download of the poster
  def redownload!
    return unless url.present?
    
    # Purge existing image if any
    image.purge if image.attached?
    
    # Queue download job
    DownloadPosterJob.perform_later(self)
  end
  
  private
  
  def has_image_or_url
    unless image.attached? || url.present?
      errors.add(:base, "Must have either an image or URL")
    end
  end
  
  def set_position
    self.position ||= (movie.movie_posters.maximum(:position) || 0) + 1
  end
  
  def should_download_image?
    url.present? && !image.attached?
  end
  
  def download_image_from_url
    DownloadPosterJob.perform_later(self)
  end
  
  def ensure_single_primary
    return unless primary?
    
    movie.movie_posters.where.not(id: id).update_all(primary: false)
  end
end
