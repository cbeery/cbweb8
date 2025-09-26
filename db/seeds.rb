# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create admin user for OAuth
admin_user = User.find_or_create_by(email: 'cb@curtbeery.com') do |user|
  user.name = 'Curt Beery'
  user.password = Devise.friendly_token[0, 20]  # Generate random password
  user.provider = 'google_oauth2'
  # user.uid = 'your-google-uid-here'  # Optional, but recommended
  user.admin = true
end