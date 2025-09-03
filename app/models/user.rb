class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  
  # Display name with fallback to email
  def display_name
    name.presence || email.split('@').first
  end

  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.provider = auth.provider
      user.uid = auth.uid
      user.name = auth.info.name
      user.image = auth.info.image
    end
  end

end
