# app/models/movie_poster.rb
class MoviePoster < ApplicationRecord
  belongs_to :movie
  has_one_attached :image

  # Validations
  validate :has_image_or_url

  # Callbacks
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
