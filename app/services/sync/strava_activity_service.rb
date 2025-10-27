# app/services/sync/strava_activity_service.rb
require 'httparty'

module Sync
  class StravaActivityService < BaseService
    include HTTParty
    base_uri 'https://www.strava.com/api/v3'
    
    # Strava rate limits: 100 requests per 15 min, 1000 per day
    RATE_LIMIT_DELAY = 0.5 # seconds between requests
    DEFAULT_DAYS_BACK = 7
    MAX_DAYS_BACK = 30
    PER_PAGE = 100 # Max allowed by Strava
    
    def initialize(sync_status: nil, broadcast: false, days_back: DEFAULT_DAYS_BACK)
      super(sync_status: sync_status, broadcast: broadcast)
      @access_token = nil
      @token_expires_at = nil
      @days_back = [days_back.to_i, MAX_DAYS_BACK].min
      @deleted_activities = []
    end
    
    protected
    
    def source_type
      'strava'
    end
    
    def fetch_items
      ensure_authenticated!
      
      log(:info, "Fetching Strava activities from last #{@days_back} days")
      
      # First, get all existing Strava IDs to detect deletions
      existing_strava_ids = StravaActivity
        .where('started_at >= ?', @days_back.days.ago)
        .pluck(:strava_id)
      
      # Fetch activities from Strava API
      activities = fetch_recent_activities
      
      # Track which activities we've seen from the API
      api_strava_ids = activities.map { |a| a['id'] }
      
      # Find deleted activities
      @deleted_activities = existing_strava_ids - api_strava_ids
      
      if @deleted_activities.any?
        log(:info, "Found #{@deleted_activities.count} deleted activities to remove")
      end
      
      log(:info, "Found #{activities.count} activities to process")
      activities
    end
    
    def process_item(activity_data)
      strava_id = activity_data['id']
      
      begin
        # Find or initialize the activity
        activity = StravaActivity.find_or_initialize_by(strava_id: strava_id)
        
        # Track if this is new or updated
        is_new = activity.new_record?
        
        # Update activity attributes
        activity.assign_attributes(
          name: activity_data['name'],
          started_at: activity_data['start_date'],
          moving_time: activity_data['moving_time'],
          elapsed_time: activity_data['elapsed_time'],
          distance: activity_data['distance'], # in meters
          activity_type: activity_data['type'],
          commute: activity_data['commute'] || false,
          gear_id: activity_data['gear_id'],
          private: activity_data['private'] || false
        )
        
        # Add location data if available
        if activity_data['start_latlng'].present?
          # Reverse geocode or use Strava's location data if available
          activity.city = extract_city(activity_data)
          activity.state = extract_state(activity_data)
        end
        
        activity.save!
        
        # Handle Ride creation/update if this is a bike ride
        if activity.activity_type == 'Ride' || activity.activity_type == 'VirtualRide'
          process_ride_record(activity, is_new)
        end
        
        if is_new
          log(:info, "Created activity: #{activity.name} (#{activity.activity_date})")
          :created
        else
          log(:debug, "Updated activity: #{activity.name}")
          :updated
        end
        
      rescue => e
        log(:error, "Failed to process activity #{strava_id}: #{e.message}")
        :failed
      ensure
        sleep RATE_LIMIT_DELAY # Rate limiting
      end
    end
    
    def describe_item(activity_data)
      "#{activity_data['name']} (#{activity_data['start_date_local']})"
    end
    
    # Override complete_sync to handle deletions
    def complete_sync
      # Process deletions after all updates
      if @deleted_activities.any?
        handle_deleted_activities
      end
      
      super # Call parent implementation
    end
    
    private
    
    def ensure_authenticated!
      return if @access_token && @token_expires_at > Time.current
      
      authenticate!
    end
    
    def authenticate!
      log(:info, "Authenticating with Strava API...")
      
      response = self.class.post(
        'https://www.strava.com/oauth/token',
        body: {
          client_id: ENV['STRAVA_CLIENT_ID'],
          client_secret: ENV['STRAVA_CLIENT_SECRET'],
          grant_type: 'refresh_token',
          refresh_token: ENV['STRAVA_REFRESH_TOKEN']
        }
      )
      
      if response.success?
        @access_token = response['access_token']
        @token_expires_at = Time.at(response['expires_at'])
        
        # Update refresh token if it changed
        if response['refresh_token'] != ENV['STRAVA_REFRESH_TOKEN']
          log(:warning, "Strava refresh token changed - update your ENV!")
          # In production, you might want to update this in your credentials store
        end
        
        log(:info, "Successfully authenticated with Strava")
      else
        raise "Failed to authenticate with Strava: #{response.body}"
      end
    end
    
    def strava_headers
      {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json'
      }
    end
    
    def fetch_recent_activities
      activities = []
      page = 1
      after_timestamp = @days_back.days.ago.to_i
      
      loop do
        response = self.class.get(
          '/athlete/activities',
          headers: strava_headers,
          query: {
            after: after_timestamp,
            per_page: PER_PAGE,
            page: page
          }
        )
        
        unless response.success?
          log(:error, "Failed to fetch activities: #{response.code} - #{response.body}")
          break
        end
        
        page_activities = response.parsed_response
        break if page_activities.empty?
        
        activities.concat(page_activities)
        
        # Check if we got less than a full page (means we're done)
        break if page_activities.size < PER_PAGE
        
        page += 1
        sleep RATE_LIMIT_DELAY # Rate limiting between pages
      end
      
      activities
    end
    
    def process_ride_record(activity, is_new)
      return unless activity.gear_id.present?
      
      # Find the bicycle by Strava gear ID
      bicycle = Bicycle.find_by(strava_gear_id: activity.gear_id)
      
      unless bicycle
        log(:warning, "No bicycle found for gear_id: #{activity.gear_id}")
        return
      end
      
      # Find or create the ride
      ride = Ride.find_or_initialize_by(
        strava_activity: activity
      )
      
      # Update ride attributes
      ride.assign_attributes(
        bicycle: bicycle,
        strava_id: activity.strava_id,
        rode_on: activity.activity_date,
        miles: activity.distance_in_miles,
        duration: activity.moving_time,
        notes: is_new ? "Synced from Strava: #{activity.name}" : ride.notes
      )
      
      if ride.save
        log(:debug, "#{is_new ? 'Created' : 'Updated'} ride for #{bicycle.name}")
      else
        log(:error, "Failed to save ride: #{ride.errors.full_messages.join(', ')}")
      end
    end
    
    def handle_deleted_activities
      log(:info, "Processing #{@deleted_activities.count} deleted activities")
      
      @deleted_activities.each do |strava_id|
        activity = StravaActivity.find_by(strava_id: strava_id)
        next unless activity
        
        activity_name = activity.name
        
        # Delete associated ride if exists
        if activity.ride
          activity.ride.destroy
          log(:info, "Deleted ride associated with activity: #{activity_name}")
        end
        
        # Delete the activity
        activity.destroy
        log(:info, "Deleted activity: #{activity_name}")
      end
    end
    
    def extract_city(activity_data)
      # Strava sometimes provides location in the summary
      if activity_data['location_city']
        activity_data['location_city']
      elsif activity_data['timezone']
        # Extract city from timezone like "America/Denver"
        activity_data['timezone'].split('/').last.tr('_', ' ')
      end
    end
    
    def extract_state(activity_data)
      # Strava sometimes provides this
      activity_data['location_state'] || 
        activity_data['location_country']
    end
  end
end
