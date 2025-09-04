class Upload < ApplicationRecord
  has_one_attached :file, dependent: :purge_later
  
  validates :title, presence: true
  validates :file, presence: true
end