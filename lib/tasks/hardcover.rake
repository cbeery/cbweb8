# lib/tasks/hardcover.rake
namespace :hardcover do
  desc "Test Hardcover API connection"
  task test_connection: :environment do
    puts "Testing Hardcover API connection..."
    
    token = ENV['HARDCOVER_ACCESS_TOKEN'] || 
            Rails.application.credentials.dig(:hardcover, :access_token)
    
    if token.blank?
      puts "❌ No access token found!"
      puts "Please set HARDCOVER_ACCESS_TOKEN environment variable"
      exit 1
    end
    
    puts "✓ Token found: #{token[0..10]}..."
    
    require 'httparty'
    
    query = <<-GRAPHQL
      query {
        me {
          id
          username
          booksCount
        }
      }
    GRAPHQL
    
    begin
      response = HTTParty.post(
        'https://api.hardcover.app/v1/graphql',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { query: query }.to_json,
        timeout: 10
      )
      
      if response.success?
        data = response.parsed_response
        
        if data['errors']
          puts "❌ GraphQL errors:"
          data['errors'].each do |error|
            puts "  - #{error['message']}"
          end
          exit 1
        elsif data['data'] && data['data']['me']
          user = data['data']['me']
          puts "✓ Successfully connected!"
          puts "  Username: #{user['username']}"
          puts "  User ID: #{user['id']}"
          puts "  Books: #{user['booksCount']}"
        else
          puts "❌ Unexpected response format"
          puts JSON.pretty_generate(data)
          exit 1
        end
      else
        puts "❌ HTTP Error: #{response.code}"
        puts response.body
        exit 1
      end
    rescue => e
      puts "❌ Connection failed: #{e.message}"
      exit 1
    end
  end
  
  desc "Sync books from Hardcover (optional: MONTHS_BACK=6)"
  task sync: :environment do
    months_back = ENV['MONTHS_BACK']&.to_i || 3
    
    puts "Starting Hardcover sync for last #{months_back} months..."
    
    sync_status = SyncStatus.create!(
      source_type: 'hardcover',
      interactive: false,
      metadata: {
        triggered_by: 'rake task',
        months_back: months_back
      }
    )
    
    begin
      service = Sync::HardcoverService.new(
        sync_status: sync_status,
        broadcast: false,
        months_back: months_back
      )
      
      service.perform
      
      puts "✓ Sync completed successfully!"
      puts "  Created: #{sync_status.reload.created_count}"
      puts "  Updated: #{sync_status.updated_count}"
      puts "  Failed: #{sync_status.failed_count}"
    rescue => e
      puts "❌ Sync failed: #{e.message}"
      exit 1
    end
  end
end