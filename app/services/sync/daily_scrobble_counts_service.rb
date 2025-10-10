# app/services/sync/daily_scrobble_counts_service.rb
require 'httparty'

module Sync
  class DailyScrobbleCountsService < BaseService
    include HTTParty
    base_uri 'http://ws.audioscrobbler.com/2.0/'
    
    USER = "flatirons" # TODO: Move to credentials
    STARTED_SCROBBLING = Date.parse("2008-02-07") # TODO: Move to config
    
    def source_type
      'lastfm_daily'
    end
    
    protected
    
    def fetch_items
      log(:info, "Determining date range for daily scrobble counts sync")
      
      # Determine which dates to sync
      dates_to_sync = determine_dates_to_sync
      
      log(:info, "Will sync #{dates_to_sync.size} days of scrobble counts")
      
      dates_to_sync
    end
    
    def process_item(date)
      from = date.to_time.to_i
      to = (date + 1.day).to_time.to_i
      
      begin
        response = self.class.get("/", query: {
          method: "user.getrecenttracks",
          user: USER,
          api_key: api_key,
          from: from,
          to: to,
          limit: 1, # We only need the total count
          format: "json"
        })
        
        handle_response(response)
        
        # Last.fm returns total in different places depending on response
        total_plays = response.dig("recenttracks", "total") || 
                     response.dig("recenttracks", "@attr", "total") || 
                     "0"
        
        total_plays = total_plays.to_i
        
        # Skip days with zero plays
        return :skipped if total_plays.zero?
        
        # Find or create the record
        daily_total = ScrobbleCount.find_or_initialize_by(played_on: date)
        
        if daily_total.persisted?
          if daily_total.plays != total_plays
            daily_total.update!(plays: total_plays)
            log(:info, "Updated count for #{date}: #{total_plays} plays")
            :updated
          else
            :skipped
          end
        else
          daily_total.plays = total_plays
          daily_total.save!
          log(:info, "Created count for #{date}: #{total_plays} plays")
          :created
        end
      rescue => e
        log(:error, "Failed to sync daily count for #{date}: #{e.message}")
        :failed
      end
    end
    
    def describe_item(date)
      date.strftime('%Y-%m-%d')
    end
    
    private
    
    def determine_dates_to_sync
      last_sync = ScrobbleCount.maximum(:played_on)
      
      if last_sync.nil?
        # Initial import - get all historical data
        log(:info, "No existing daily counts found, will import all history since #{STARTED_SCROBBLING}")
        (STARTED_SCROBBLING..Date.today).to_a
      else
        # Incremental sync - get days since last sync, plus last 7 days to catch updates
        start_date = [last_sync - 7.days, STARTED_SCROBBLING].max
        end_date = Date.today
        
        log(:info, "Syncing from #{start_date} to #{end_date}")
        (start_date..end_date).to_a
      end
    end
    
    def handle_response(response)
      unless response.success?
        raise "Last.fm API request failed: #{response.code} #{response.message}"
      end
      response
    end
    
    def api_key
      @api_key ||= Rails.application.credentials.dig(:lastfm, :api_key) ||
                   ENV['LASTFM_API_KEY'] ||
                   raise("Last.fm API key not configured")
    end
  end
end