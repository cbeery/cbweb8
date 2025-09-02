class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  
  # Display name with fallback to email
  def display_name
    name.presence || email.split('@').first
  end
end
