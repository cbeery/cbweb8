# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }

  has_many :sync_statuses, dependent: :nullify
  has_many :log_entries, dependent: :nullify
  
  # Display name with fallback to email
  def display_name
    name.presence || email.split('@').first
  end

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_initialize do |u|
      u.password = Devise.friendly_token[0, 20]
    end
    
    # Always update these attributes to keep them fresh
    user.provider = auth.provider
    user.uid = auth.uid
    user.name = auth.info.name
    user.image = auth.info.image
    
    user.save! if user.new_record? || user.changed?
    user
  end
end