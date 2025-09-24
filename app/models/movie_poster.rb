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
  # after_create :download_image_from_url, if: :url?
  after_save :ensure_single_primary
  
  def display_image_url
    if image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
    else
      url
    end
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
  
  # def download_image_from_url
  #   return unless url.present?
    
  #   DownloadPosterJob.perform_later(self)
  # end
  
  def ensure_single_primary
    return unless primary?
    
    movie.movie_posters.where.not(id: id).update_all(primary: false)
  end
end