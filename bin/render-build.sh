#!/usr/bin/env bash
# exit on error
set -o errexit

# Install dependencies
bundle install

bundle exec rails tailwindcss:build

# Precompile assets
bundle exec rails assets:precompile

# Clean up old assets
bundle exec rails assets:clean

# Run database migrations
bundle exec rails db:migrate

# Create first admin user if doesn't exist (for OAuth/Google authentication)
bundle exec rails runner "User.find_or_create_by(email: ENV['ADMIN_EMAIL']) do |u|
  u.name = ENV['ADMIN_NAME'] || 'Admin'
  u.admin = true
  u.provider = 'google_oauth2'
  u.uid = ENV['ADMIN_GOOGLE_UID'] if ENV['ADMIN_GOOGLE_UID'].present?
end if ENV['ADMIN_EMAIL'].present?"
