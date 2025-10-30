# app/models/page.rb
class Page < ApplicationRecord
  # ActionText
  has_rich_text :content
  
  # Validations
  validates :slug, presence: true, uniqueness: true, 
            format: { with: /\A[a-z0-9-]+\z/, 
                     message: "can only contain lowercase letters, numbers, and hyphens" }
  validates :name, presence: true
  
  # Scopes
  scope :published, -> { where.not(published_on: nil).where("published_on <= ?", Date.current) }
  scope :drafts, -> { where(published_on: nil) }
  scope :publicly_visible, -> { where(public: true) }
  scope :in_index, -> { where(show_in_index: true) }
  scope :recent_first, -> { order(published_on: :desc) }
  scope :alphabetical, -> { order(:name) }
  scope :for_recent_section, -> { where(show_in_recent: true) }
  scope :search_engine_visible, -> { where(hide_from_search_engines: false) }
  
  # Callbacks
  before_validation :normalize_slug
  
  # Methods
  def published?
    published_on.present? && published_on <= Date.current
  end
  
  def draft?
    !published?
  end
  
  def display_status
    if published?
      "Published on #{published_on.strftime('%B %-d, %Y')}"
    else
      "Draft"
    end
  end
  
  def to_param
    slug
  end
  
  private
  
  def normalize_slug
    return unless slug.present?
    self.slug = slug.downcase.strip.gsub(/[^a-z0-9-]/, '-').squeeze('-').gsub(/^-|-$/, '')
  end
end
