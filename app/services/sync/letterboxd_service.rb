# app/services/sync/letterboxd_service.rb
require 'feedjira'
require 'open-uri'

# Syncs movie viewings from Letterboxd RSS feed
# 
# Normal sync: Only processes new entries since last sync
# Re-sync mode: Re-processes all recent entries to catch rating updates
#   To trigger re-sync: sync_status.metadata['resync_recent'] = true
#
# Note: Letterboxd RSS doesn't update entries when ratings change,
# so rating updates are only caught during re-sync or when the RSS
# feed happens to include older entries
module Sync
  class LetterboxdService < BaseService
    def source_type
      'letterboxd'
    end

    protected

    def fetch_items
      rss_url = Rails.application.credentials.dig(:letterboxd, :rss_url) || 
                ENV['LETTERBOXD_RSS_URL']
      
      raise "Letterboxd RSS URL not configured" if rss_url.blank?
      
      log(:info, "Fetching RSS feed", url: rss_url)
      
      # Parse feed with Feedjira
      xml = URI.open(rss_url).read
      feed = Feedjira.parse(xml)
      
      # Store feed metadata
      sync_status.update!(
        metadata: sync_status.metadata.merge(
          rss_url: rss_url,
          feed_title: feed.title,
          feed_description: feed.description,
          last_build_date: feed.last_built || feed.last_modified,
          feed_url: feed.feed_url,
          etag: feed.etag
        )
      )
      
      # Check if we're doing a full re-sync of recent items
      if sync_status.metadata['resync_recent']
        log(:info, "Re-syncing recent entries to catch updates")
        feed.entries
      else
        # Normal sync - only process truly new entries
        filter_new_entries(feed.entries)
      end
    end
    
    def filter_new_entries(entries)
      last_seen_id = sync_status.metadata['last_entry_id']
      last_seen_date = sync_status.metadata['last_entry_date']
      
      return entries if last_seen_id.nil? && last_seen_date.nil?
      
      # Filter to only entries we haven't seen before
      entries.select do |entry|
        entry_id = entry.entry_id || entry.id
        entry_date = entry.published
        
        # Include if it's newer than our last seen entry
        (entry_date && last_seen_date && entry_date > Time.parse(last_seen_date)) ||
        (entry_id && entry_id != last_seen_id)
      end
    end

    def process_item(entry)
      # Parse the RSS entry
      movie_data = parse_letterboxd_entry(entry)
      
      # Find or create movie
      movie = Movie.find_or_create_by(
        title: movie_data[:title],
        year: movie_data[:year]
      ) do |m|
        m.letterboxd_id = movie_data[:letterboxd_id]
        m.url = entry.url
        log(:info, "Creating new movie", title: m.title, year: m.year)
      end
      
      # Always update movie rating if provided (to catch rating changes)
      if movie_data[:rating].present? && movie.rating != movie_data[:rating]
        old_rating = movie.rating
        movie.update!(rating: movie_data[:rating])
        log(:info, "Updated movie rating", 
          movie: movie.title,
          old_rating: old_rating,
          new_rating: movie_data[:rating]
        )
      end

      # Create or update viewing
      viewing = Viewing.find_or_initialize_by(
        movie: movie,
        viewed_on: movie_data[:viewed_on]
      )
      
      if viewing.new_record?
        viewing.assign_attributes(
          notes: movie_data[:review],
          rewatch: determine_rewatch(movie)
        )
        viewing.save!
        
        log(:success, "Created viewing", 
          movie: movie.title,
          rating: movie_data[:rating],
          viewed_on: movie_data[:viewed_on]
        )
        :created
      elsif viewing.notes != movie_data[:review]
        viewing.update!(
          notes: movie_data[:review]
        )
        
        log(:info, "Updated viewing", 
          movie: movie.title,
          notes_changed: true
        )
        :updated
      else
        :skipped
      end
      
    rescue StandardError => e
      log(:error, "Failed to process Letterboxd entry", 
        error: e.class.name,
        message: e.message,
        entry_title: entry.title,
        entry_url: entry.url
      )
      :failed
    end

    def describe_item(entry)
      # Extract movie title from entry title
      # Letterboxd format is usually "Movie Title, Year - ★★★★"
      entry.title.split(' - ').first || entry.title
    end

    private

    def parse_letterboxd_entry(entry)
      # Parse title and year
      title_match = entry.title.match(/^(.+?),\s*(\d{4})/)
      title = title_match ? title_match[1] : entry.title.split(' - ').first
      year = title_match ? title_match[2].to_i : nil
      
      # Parse rating (if present)
      rating = parse_rating(entry.title)
      
      # Parse watched date from published date
      viewed_on = entry.published&.to_date
      
      # Extract review text if present
      review = parse_review(entry.summary || entry.content)
      
      # Get Letterboxd ID (film slug)
      letterboxd_id = extract_letterboxd_id(entry)
      
      {
        title: title,
        year: year,
        rating: rating,
        viewed_on: viewed_on,
        review: review,
        letterboxd_id: letterboxd_id
      }
    end
    
    def parse_rating(title)
      # Count stars in title
      stars = title.scan('★').count
      half_star = title.include?('½')
      
      return nil if stars == 0 && !half_star
      
      rating = stars.to_f
      rating += 0.5 if half_star
      rating
    end
    
    def parse_review(content)
      return nil if content.blank?
      
      # Remove HTML tags and clean up
      text = ActionView::Base.full_sanitizer.sanitize(content)
      text.strip.presence
    end
    
    def extract_letterboxd_id(entry)
      # Extract film slug from URL
      # Format: https://letterboxd.com/username/film/movie-slug/
      if entry.url =~ %r{/film/([^/]+)/?}
        $1
      end
    end
    
    def determine_rewatch(movie)
      # Check if this movie has been watched before
      movie.viewings.any?
    end
    
    # Store last sync position for incremental syncs
    # This should be called after processing all items
    # If BaseService has an after_sync hook, use that:
    #   def after_sync(items)
    #     store_sync_position(items)
    #   end
    def store_sync_position(entries)
      return if entries.empty?
      
      newest_entry = entries.first
      
      # Only update last seen markers if not doing a re-sync
      unless sync_status.metadata['resync_recent']
        sync_status.metadata['last_entry_id'] = newest_entry.entry_id || newest_entry.id
        sync_status.metadata['last_entry_date'] = newest_entry.published&.iso8601
      end
      
      # Clear the resync flag after use
      sync_status.metadata.delete('resync_recent')
      sync_status.save!
    end

    # Optional: Support conditional fetching with ETags
    def fetch_items_with_etag
      rss_url = Rails.application.credentials.dig(:letterboxd, :rss_url) || 
                ENV['LETTERBOXD_RSS_URL']
      
      raise "Letterboxd RSS URL not configured" if rss_url.blank?
      
      log(:info, "Fetching RSS feed with ETag support", url: rss_url)
      
      # Configure Feedjira options
      options = {}
      
      # Use stored ETag if available for conditional fetching
      if sync_status.metadata['etag'].present?
        options[:if_none_match] = sync_status.metadata['etag']
      end
      
      # Use stored last modified date if available
      if sync_status.metadata['last_modified'].present?
        options[:if_modified_since] = sync_status.metadata['last_modified']
      end
      
      # Fetch and parse feed
      feed = Feedjira::Feed.fetch_and_parse(rss_url, options)
      
      # Check if feed hasn't changed (304 Not Modified)
      if feed == 304
        log(:info, "Feed not modified since last fetch")
        return []
      end
      
      # Store new ETag and metadata
      sync_status.update!(
        metadata: sync_status.metadata.merge(
          rss_url: rss_url,
          feed_title: feed.title,
          feed_description: feed.description,
          last_build_date: feed.last_built || feed.last_modified,
          feed_url: feed.feed_url,
          etag: feed.etag,
          last_modified: feed.last_modified
        )
      )
      
      feed.entries
    end
  end
end