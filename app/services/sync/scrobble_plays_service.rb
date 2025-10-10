# app/services/sync/scrobble_plays_service.rb
require 'httparty'

module Sync
  class ScrobblePlaysService < BaseService
    include HTTParty
    base_uri 'http://ws.audioscrobbler.com/2.0/'
    
    USER = "flatirons" # TODO: Move to credentials
    
    def source_type
      'lastfm'
    end
    
    protected
    
    def fetch_items
      log(:info, "Fetching Last.fm weekly chart list")
      
      response = self.class.get("/", query: {
        method: "user.getWeeklyChartList",
        user: USER,
        api_key: api_key,
        format: "json"
      })
      
      handle_response(response)
      weeks = response.dig("weeklychartlist", "chart") || []
      
      log(:info, "Found #{weeks.size} total weekly charts")
      
      # Return last 52 weeks by default, or all if doing initial import
      weeks_to_process = determine_weeks_to_process(weeks)
      
      log(:info, "Will process #{weeks_to_process.size} weeks")
      
      # Convert to our own Week objects that we'll process
      weeks_to_process.map do |week|
        WeekToProcess.new(
          from: week["from"],
          to: week["to"],
          end_date: Time.at(week["to"].to_i).to_date
        )
      end
    end
    
    def process_item(week)
      log(:info, "Processing week ending #{week.end_date}")
      
      artist_results = sync_weekly_artists(week)
      album_results = sync_weekly_albums(week)
      
      # Determine overall result for this week
      if artist_results[:failed] > 0 || album_results[:failed] > 0
        :failed
      elsif artist_results[:created] > 0 || album_results[:created] > 0
        :created
      elsif artist_results[:updated] > 0 || album_results[:updated] > 0
        :updated
      else
        :skipped
      end
    end
    
    def describe_item(week)
      "Week ending #{week.end_date.strftime('%Y-%m-%d')}"
    end
    
    private
    
    WeekToProcess = Struct.new(:from, :to, :end_date, keyword_init: true)
    
    def determine_weeks_to_process(weeks)
      # Check if we have any existing data
      last_sync = ScrobblePlay.maximum(:played_on)
      
      if last_sync.nil?
        # Initial import - get all weeks
        log(:info, "No existing data found, will import all weeks")
        weeks
      else
        # Incremental sync - get weeks since last sync
        weeks_since_last_sync = weeks.select do |week|
          Time.at(week["to"].to_i).to_date > last_sync
        end
        
        if weeks_since_last_sync.empty?
          # No new weeks, just get last 4 weeks to catch any updates
          log(:info, "No new weeks found, checking last 4 weeks for updates")
          weeks.last(10)
        else
          log(:info, "Found #{weeks_since_last_sync.size} new weeks since #{last_sync}")
          weeks_since_last_sync
        end
      end
    end
    
    def sync_weekly_artists(week)
      results = { created: 0, updated: 0, failed: 0 }
      
      begin
        response = self.class.get("/", query: {
          method: "user.getWeeklyArtistChart",
          user: USER,
          api_key: api_key,
          from: week.from,
          to: week.to,
          format: "json"
        })
        
        handle_response(response)
        artists = response.dig("weeklyartistchart", "artist")
        
        return results if artists.nil?
        
        # Handle single artist as Hash
        artists = [artists] if artists.is_a?(Hash)
        
        artists.each do |artist_data|
          result = process_artist_play(artist_data, week.end_date)
          results[result] += 1 if results.key?(result)
        end
        
        log(:info, "Artists - Created: #{results[:created]}, Updated: #{results[:updated]}, Failed: #{results[:failed]}",
            week: week.end_date)
      rescue => e
        log(:error, "Failed to sync weekly artists: #{e.message}", 
            week: week.end_date)
        results[:failed] = 1
      end
      
      results
    end
    
    def sync_weekly_albums(week)
      results = { created: 0, updated: 0, failed: 0 }
      
      begin
        response = self.class.get("/", query: {
          method: "user.getWeeklyAlbumChart",
          user: USER,
          api_key: api_key,
          from: week.from,
          to: week.to,
          format: "json"
        })
        
        handle_response(response)
        albums = response.dig("weeklyalbumchart", "album")
        
        return results if albums.nil?
        
        # Handle single album as Hash
        albums = [albums] if albums.is_a?(Hash)
        
        albums.each do |album_data|
          result = process_album_play(album_data, week.end_date)
          results[result] += 1 if results.key?(result)
        end
        
        log(:info, "Albums - Created: #{results[:created]}, Updated: #{results[:updated]}, Failed: #{results[:failed]}",
            week: week.end_date)
      rescue => e
        log(:error, "Failed to sync weekly albums: #{e.message}",
            week: week.end_date)
        results[:failed] = 1
      end
      
      results
    end
    
    def process_artist_play(artist_data, end_date)
      artist_name = artist_data["name"]
      plays = artist_data["playcount"].to_i
      
      return :skipped if artist_name.blank? || plays.zero?
      
      artist = ScrobbleArtist.find_or_create_by(name: artist_name)
      
      existing_play = ScrobblePlay.artists
                                  .where(scrobble_artist: artist, played_on: end_date)
                                  .first
      
      if existing_play
        if existing_play.plays != plays
          existing_play.update!(plays: plays)
          :updated
        else
          :skipped
        end
      else
        ScrobblePlay.create!(
          category: "artist",
          scrobble_artist: artist,
          played_on: end_date,
          plays: plays
        )
        :created
      end
    rescue => e
      log(:error, "Failed to process artist: #{e.message}",
          artist: artist_name,
          week: end_date)
      :failed
    end
    
    def process_album_play(album_data, end_date)
      album_name = album_data["name"]
      artist_name = album_data.dig("artist", "#text")
      plays = album_data["playcount"].to_i
      
      return :skipped if album_name.blank? || artist_name.blank? || plays.zero?
      
      artist = ScrobbleArtist.find_or_create_by(name: artist_name)
      album = ScrobbleAlbum.find_or_create_by(
        name: album_name,
        scrobble_artist: artist
      )
      
      existing_play = ScrobblePlay.albums
                                  .where(
                                    scrobble_album: album,
                                    scrobble_artist: artist,
                                    played_on: end_date
                                  )
                                  .first
      
      if existing_play
        if existing_play.plays != plays
          existing_play.update!(plays: plays)
          :updated
        else
          :skipped
        end
      else
        ScrobblePlay.create!(
          category: "album",
          scrobble_album: album,
          scrobble_artist: artist,
          played_on: end_date,
          plays: plays
        )
        :created
      end
    rescue => e
      log(:error, "Failed to process album: #{e.message}",
          album: album_name,
          artist: artist_name,
          week: end_date)
      :failed
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