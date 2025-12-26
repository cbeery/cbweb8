class TopScrobbleImage < ApplicationRecord
  # Statuses
  PENDING = 'pending'.freeze
  FOUND = 'found'.freeze
  NOT_FOUND = 'not_found'.freeze

  STATUSES = [PENDING, FOUND, NOT_FOUND].freeze
  CATEGORIES = %w[artist album track].freeze

  # Validations
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :artist, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :category, uniqueness: { scope: [:artist, :name] }

  # Scopes
  scope :pending, -> { where(status: PENDING) }
  scope :found, -> { where(status: FOUND) }
  scope :not_found, -> { where(status: NOT_FOUND) }
  scope :artists, -> { where(category: 'artist') }
  scope :albums, -> { where(category: 'album') }
  scope :tracks, -> { where(category: 'track') }

  # Find or create an image record for a scrobble
  # Returns the image record (may be pending, found, or not_found)
  def self.find_or_create_for(category:, artist:, name: nil)
    # Normalize name to nil for artists (they don't have album/track names)
    name = nil if category == 'artist'

    find_or_create_by!(category: category, artist: artist, name: name)
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition
    find_by!(category: category, artist: artist, name: name)
  end

  # Lookup key used for matching
  def lookup_key
    [category, artist, name].compact.join('::')
  end

  def pending?
    status == PENDING
  end

  def found?
    status == FOUND
  end

  def not_found?
    status == NOT_FOUND
  end

  def has_image?
    found? && image_url.present?
  end

  # Mark as found with the given URL
  def mark_found!(url:, spotify_id: nil)
    update!(
      status: FOUND,
      image_url: url,
      spotify_id: spotify_id
    )
  end

  # Mark as not found (no image available)
  def mark_not_found!
    update!(status: NOT_FOUND)
  end
end
