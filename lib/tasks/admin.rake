namespace :admin do
  desc "Create first admin user"
  task create_user: :environment do
    if ENV['ADMIN_EMAIL'].present?
      User.find_or_create_by(email: ENV['ADMIN_EMAIL']) do |u|
        u.name = ENV['ADMIN_NAME'] || 'Admin'
        u.admin = true
        u.provider = 'google_oauth2'
        u.uid = ENV['ADMIN_GOOGLE_UID'] if ENV['ADMIN_GOOGLE_UID'].present?
      end
      puts "Admin user created/updated: #{ENV['ADMIN_EMAIL']}"
    end
  end
end
