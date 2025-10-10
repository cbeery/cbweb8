# app/services/sync/top_scrobbles_service.rb
require 'httparty'

module Sync
  class TopScrobblesService < BaseService
    include HTTParty
    base_uri 'http://ws.audioscrobbler.com/2.0/'
    
    USER = "flatirons" # TODO: Move to credentials
    
    PERIODS = %w[7day 1month 3month 6month 12month overall].freeze
    
    CATEGORIES = [
      { name: 'artist', method: 'user.gettopartists' },
      { name: 'album',  method: 'user.gettopalbums' },
      { name: 'track',  method: 'user.gettoptracks' }
    ].freeze
    
    TOP_ITEMS_LIMIT = 50 # Last.fm API can return up to 50
    
    def source_type
      'lastfm_top'
    end
    
    protected
    
    def fetch_items
      log(:info, "Building top scrobbles sync tasks")
      
      # Create a task for each category/period combination
      tasks = []
      
      CATEGORIES.each do |category|
        PERIODS.each do |period|
          tasks << TopScrobbleTask.new(
            category: category[:name],
            method: category[:method],
            period: period
          )
        end
      end
      
      log(:info, "Will process #{tasks.size} top scrobble tasks (#{CATEGORIES.size} categories × #{PERIODS.size} periods)")
      
      tasks
    end
    
    def process_item(task)
      log(:info, "Fetching top #{task.category}s for #{task.period}")
      
      begin
        response = self.class.get("/", query: {
          method: task.method,
          user: USER,
          api_key: api_key,
          period: task.period,
          limit: TOP_ITEMS_LIMIT,
          format: "json"
        })
        
        handle_response(response)
        
        # Parse the response - structure varies by category
        items = extract_items_from_response(response, task.category)
        
        if items.nil? || items.empty?
          log(:info, "No items found for #{task.category}/#{task.period}")
          return :skipped
        end
        
        # Ensure items is an array (API returns single item as Hash sometimes)
        items = [items] if items.is_a?(Hash)
        
        results = process_top_items(items, task)
        
        log(:info, "Processed #{items.size} items - Created: #{results[:created]}, Updated: #{results[:updated]}")
        
        # Return overall status
        if results[:failed] > 0
          :failed
        elsif results[:created] > 0
          :created
        elsif results[:updated] > 0
          :updated
        else
          :skipped
        end
      rescue => e
        log(:error, "Failed to sync top #{task.category}s for #{task.period}: #{e.message}")
        :failed
      end
    end
    
    def describe_item(task)
      "#{task.category.capitalize}s for #{task.period}"
    end
    
    private
    
    TopScrobbleTask = Struct.new(:category, :method, :period, keyword_init: true)
    
    def extract_items_from_response(response, category)
      # Response structure: { "topartists": { "artist": [...] } }
      # or { "topalbums": { "album": [...] } }
      # or { "toptracks": { "track": [...] } }
      key = "top#{category}s"
      response.dig(key, category)
    end
    
    def process_top_items(items, task)
      results = { created: 0, updated: 0, failed: 0 }
      
      # Process each position (1-based indexing)
      items.each_with_index do |item, index|
        position = index + 1
        
        begin
          result = process_single_top_item(item, task, position)
          results[result] += 1 if results.key?(result)
        rescue => e
          log(:error, "Failed to process position #{position}: #{e.message}")
          results[:failed] += 1
        end
      end
      
      # Clear out any positions beyond what we received
      # (e.g., if we only got 30 items but previously had 50)
      clear_remaining_positions(task, items.size + 1)
      
      results
    end
    
    def process_single_top_item(item, task, position)
      # Extract data based on category
      rank = item.dig('@attr', 'rank')&.to_i || position
      plays = item['playcount']&.to_i || 0
      url = item['url'] || ''
      
      artist_name, item_name = extract_names(item, task.category)
      
      # Find existing record or build a new one
      scrobble = TopScrobble.where(
        category: task.category,
        period: task.period,
        position: position
      ).first_or_initialize
      
      # Check if we need to update
      new_attributes = {
        artist: artist_name,
        name: item_name,
        plays: plays,
        rank: rank,
        url: url,
        revised_at: Time.current
      }
      
      if scrobble.new_record?
        scrobble.assign_attributes(new_attributes)
        scrobble.save!
        :created
      elsif attributes_changed?(scrobble, new_attributes)
        scrobble.update!(new_attributes)
        :updated
      else
        :skipped
      end
    rescue ActiveRecord::RecordNotUnique => e
      # Handle race condition - record was created between our check and save
      log(:warn, "Record already exists for #{task.category}/#{task.period}/#{position}, updating instead")
      
      scrobble = TopScrobble.find_by!(
        category: task.category,
        period: task.period,
        position: position
      )
      
      if attributes_changed?(scrobble, new_attributes)
        scrobble.update!(new_attributes)
        :updated
      else
        :skipped
      end
    end
    
    def extract_names(item, category)
      case category
      when 'artist'
        artist_name = item['name'] || ''
        item_name = ''
      when 'album', 'track'
        artist_name = item.dig('artist', 'name') || ''
        item_name = item['name'] || ''
      else
        artist_name = ''
        item_name = ''
      end
      
      [artist_name, item_name]
    end
    
    def attributes_changed?(scrobble, new_attributes)
      # Check if any relevant attributes have changed
      %i[artist name plays rank url].any? do |attr|
        scrobble.public_send(attr) != new_attributes[attr]
      end
    end
    
    def clear_remaining_positions(task, start_position)
      # Remove any TopScrobbles beyond the positions we just processed
      # This handles cases where we previously had more items than we do now
      TopScrobble.where(
        category: task.category,
        period: task.period,
        position: start_position..
      ).destroy_all
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
