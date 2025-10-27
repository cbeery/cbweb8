# lib/tasks/strava.rake
namespace :strava do
  desc "Sync recent Strava activities (default: last 7 days)"
  task :sync, [:days_back] => :environment do |t, args|
    days_back = args[:days_back]&.to_i || 7
    
    puts "Starting Strava sync for last #{days_back} days..."
    
    sync_status = SyncStatus.create!(
      source_type: 'strava',
      interactive: false,
      metadata: {
        triggered_by: 'rake',
        days_back: days_back,
        started_at: Time.current.iso8601
      }
    )
    
    service = Sync::StravaActivityService.new(
      sync_status: sync_status,
      broadcast: false,
      days_back: days_back
    )
    
    service.perform
    
    puts "Strava sync completed!"
    puts "Results: #{sync_status.reload.metadata}"
  end
  
  desc "Full Strava sync (last 30 days - maximum allowed)"
  task full_sync: :environment do
    Rake::Task["strava:sync"].invoke(30)
  end
  
  desc "Test Strava authentication"
  task test_auth: :environment do
    require 'httparty'
    
    puts "Testing Strava authentication..."
    
    response = HTTParty.post(
      'https://www.strava.com/oauth/token',
      body: {
        client_id: ENV['STRAVA_CLIENT_ID'],
        client_secret: ENV['STRAVA_CLIENT_SECRET'],
        grant_type: 'refresh_token',
        refresh_token: ENV['STRAVA_REFRESH_TOKEN']
      }
    )
    
    if response.success?
      puts "✓ Authentication successful!"
      puts "  Access token: #{response['access_token'][0..20]}..."
      puts "  Expires at: #{Time.at(response['expires_at'])}"
      
      # Athlete data might not be included in refresh token response
      if response['athlete'].present?
        puts "  Athlete ID: #{response['athlete']['id']}"
        puts "  Athlete name: #{response['athlete']['firstname']} #{response['athlete']['lastname']}"
      else
        puts "  Note: Athlete data not included in refresh response"
        
        # Make a separate API call to get athlete info
        puts "\nFetching athlete details..."
        athlete_response = HTTParty.get(
          'https://www.strava.com/api/v3/athlete',
          headers: {
            'Authorization' => "Bearer #{response['access_token']}"
          }
        )
        
        if athlete_response.success?
          athlete = athlete_response.parsed_response
          puts "  Athlete ID: #{athlete['id']}"
          puts "  Athlete name: #{athlete['firstname']} #{athlete['lastname']}"
          puts "  Profile: #{athlete['username']}" if athlete['username']
        else
          puts "  Could not fetch athlete details: #{athlete_response.code}"
        end
      end
    else
      puts "✗ Authentication failed!"
      puts "  Status: #{response.code}"
      puts "  Error: #{response.body}"
    end
  end
  
  desc "List bikes with Strava gear IDs"
  task list_gear: :environment do
    puts "\nBikes with Strava Gear IDs:"
    puts "=" * 60
    
    Bicycle.where.not(strava_gear_id: nil).each do |bike|
      rides_count = bike.rides.with_strava.count
      last_sync = bike.rides.with_strava.recent.first&.rode_on
      
      puts "#{bike.name}"
      puts "  Gear ID: #{bike.strava_gear_id}"
      puts "  Strava Rides: #{rides_count}"
      puts "  Last Sync: #{last_sync || 'Never'}"
      puts ""
    end
    
    puts "\nBikes WITHOUT Strava Gear IDs:"
    puts "-" * 40
    Bicycle.where(strava_gear_id: nil).each do |bike|
      puts "- #{bike.name} (#{bike.rides.count} rides)"
    end
  end
  
  desc "Match unlinked Strava activities to rides"
  task match_rides: :environment do
    puts "Finding unlinked Strava ride activities..."
    
    unlinked = StravaActivity.rides
                            .left_joins(:ride)
                            .where(rides: { id: nil })
                            .where.not(gear_id: nil)
    
    puts "Found #{unlinked.count} unlinked ride activities"
    
    created = 0
    skipped = 0
    
    unlinked.find_each do |activity|
      bicycle = Bicycle.find_by(strava_gear_id: activity.gear_id)
      
      if bicycle.nil?
        puts "  ⚠ No bicycle for gear #{activity.gear_id}"
        skipped += 1
        next
      end
      
      # Check if a ride already exists for this date/bike
      existing = Ride.where(
        bicycle: bicycle,
        rode_on: activity.activity_date,
        strava_id: activity.strava_id
      ).first
      
      if existing
        # Link them
        existing.update!(strava_activity: activity)
        puts "  ↔ Linked existing ride to #{activity.name}"
      else
        # Create new ride
        ride = Ride.create!(
          bicycle: bicycle,
          strava_activity: activity,
          strava_id: activity.strava_id,
          rode_on: activity.activity_date,
          miles: activity.distance_in_miles,
          duration: activity.moving_time,
          notes: "Matched from Strava: #{activity.name}"
        )
        created += 1
        puts "  ✓ Created ride for #{activity.name}"
      end
    end
    
    puts "\nCompleted: #{created} rides created, #{skipped} skipped"
  end
  
  desc "Show Strava sync statistics"
  task stats: :environment do
    puts "\nStrava Activity Statistics"
    puts "=" * 60
    
    total = StravaActivity.count
    by_type = StravaActivity.group(:activity_type).count
    recent = StravaActivity.where('started_at >= ?', 30.days.ago).count
    with_rides = StravaActivity.joins(:ride).count
    
    puts "Total Activities: #{total}"
    puts "Last 30 days: #{recent}"
    puts "Linked to Rides: #{with_rides}"
    puts "\nBy Type:"
    by_type.sort_by { |_, count| -count }.each do |type, count|
      puts "  #{type}: #{count}"
    end
    
    puts "\nGear Usage:"
    gear_usage = StravaActivity.where.not(gear_id: nil)
                              .group(:gear_id)
                              .count
                              .sort_by { |_, count| -count }
    
    gear_usage.each do |gear_id, count|
      bike = Bicycle.find_by(strava_gear_id: gear_id)
      bike_name = bike&.name || "Unknown (#{gear_id})"
      puts "  #{bike_name}: #{count} activities"
    end
    
    last_sync = SyncStatus.where(source_type: 'strava')
                         .order(created_at: :desc)
                         .first
    
    if last_sync
      puts "\nLast Sync:"
      puts "  Time: #{last_sync.created_at}"
      puts "  Status: #{last_sync.status}"
      puts "  Results: #{last_sync.metadata}"
    end
  end
  
  desc "Test API connectivity with sample fetch"
  task test_api: :environment do
    require 'httparty'
    
    puts "Testing Strava API connectivity..."
    
    # First authenticate
    auth_response = HTTParty.post(
      'https://www.strava.com/oauth/token',
      body: {
        client_id: ENV['STRAVA_CLIENT_ID'],
        client_secret: ENV['STRAVA_CLIENT_SECRET'],
        grant_type: 'refresh_token',
        refresh_token: ENV['STRAVA_REFRESH_TOKEN']
      }
    )
    
    unless auth_response.success?
      puts "✗ Authentication failed: #{auth_response.code}"
      exit 1
    end
    
    access_token = auth_response['access_token']
    puts "✓ Authenticated successfully"
    
    # Test fetching athlete
    puts "\nFetching athlete profile..."
    athlete_response = HTTParty.get(
      'https://www.strava.com/api/v3/athlete',
      headers: { 'Authorization' => "Bearer #{access_token}" }
    )
    
    if athlete_response.success?
      athlete = athlete_response.parsed_response
      puts "✓ Athlete: #{athlete['firstname']} #{athlete['lastname']} (ID: #{athlete['id']})"
    else
      puts "✗ Failed to fetch athlete: #{athlete_response.code}"
    end
    
    # Test fetching activities
    puts "\nFetching recent activities..."
    activities_response = HTTParty.get(
      'https://www.strava.com/api/v3/athlete/activities',
      headers: { 'Authorization' => "Bearer #{access_token}" },
      query: { per_page: 5 }
    )
    
    if activities_response.success?
      activities = activities_response.parsed_response
      puts "✓ Found #{activities.size} recent activities:"
      
      activities.each do |activity|
        miles = (activity['distance'] * 0.000621371).round(2)
        minutes = (activity['moving_time'] / 60.0).round
        puts "  - #{activity['name']}: #{miles} miles in #{minutes} min (#{activity['type']})"
        
        if activity['gear_id'].present?
          bike = Bicycle.find_by(strava_gear_id: activity['gear_id'])
          if bike
            puts "    → Gear matched to: #{bike.name}"
          else
            puts "    → Gear #{activity['gear_id']} not mapped to any bicycle"
          end
        end
      end
    else
      puts "✗ Failed to fetch activities: #{activities_response.code}"
    end
  end
end
