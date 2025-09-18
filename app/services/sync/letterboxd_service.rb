# app/services/sync/letterboxd_service.rb
# require 'rss'
require 'open-uri'

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
      
      feed = RSS::Parser.parse(URI.open(rss_url))
      
      # Store feed metadata
      sync_status.update!(
        metadata: sync_status.metadata.merge(
          rss_url: rss_url,
          feed_title: feed.channel.title,
          feed_description: feed.channel.description,
          last_build_date: feed.channel.lastBuildDate
        )
      )
      
      feed.items
    end

    def process_item(item)
      # Parse the RSS item
      movie_data = parse_letterboxd_item(item)
      
      # Find or create movie
      movie = Movie.find_or_create_by(
        title: movie_data[:title],
        year: movie_data[:year]
      ) do |m|
        m.letterboxd_uri = movie_data[:letterboxd_uri]
        log(:info, "Creating new movie", title: m.title, year: m.year)
      end

      # Create or update viewing
      viewing = Viewing.find_or_initialize_by(
        movie: movie,
        watched_at: movie_data[:watched_at]
      )
      
      if viewing.new_record?
        viewing.assign_attributes(
          rating: movie_data[:rating],
          review: movie_data[:review],
          letterboxd_uri: item.link
        )
        viewing.save!
        
        log(:success, "Created viewing", 
          movie: movie.title,
          rating: movie_data[:rating],
          watched_at: movie_data[:watched_at]
        )
        :created
      elsif viewing.rating != movie_data[:rating] || viewing.review != movie_data[:review]
        viewing.update!(
          rating: movie_data[:rating],
          review: movie_data[:review]
        )
        
        log(:info, "Updated viewing", 
          movie: movie.title,
          old_rating: viewing.rating_was,
          new_rating: movie_data[:rating]
        )
        :updated
      else
        :skipped
      end
      
    rescue StandardError => e
      log(:error, "Failed to process Letterboxd item", 
        error: e.class.name,
        message: e.message,
        item_title: item.title,
        item_link: item.link
      )
      :failed
    end

    def describe_item(item)
      # Extract movie title from item title
      # Letterboxd format is usually "Movie Title, Year - ★★★★"
      item.title.split(' - ').first || item.title
    end

    private

    def parse_letterboxd_item(item)
      # Parse title and year
      title_match = item.title.match(/^(.+?),\s*(\d{4})/)
      title = title_match ? title_match[1] : item.title.split(' - ').first
      year = title_match ? title_match[2].to_i : nil
      
      # Parse rating (if present)
      rating = parse_rating(item.title)
      
      # Parse watched date from pubDate
      watched_at = item.pubDate || item.date
      
      # Extract review text if present
      review = parse_review(item.description)
      
      # Get Letterboxd URI
      letterboxd_uri = extract_letterboxd_uri(item)
      
      {
        title: title,
        year: year,
        rating: rating,
        watched_at: watched_at,
        review: review,
        letterboxd_uri: letterboxd_uri
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
    
    def parse_review(description)
      return nil if description.blank?
      
      # Remove HTML tags and clean up
      text = ActionView::Base.full_sanitizer.sanitize(description)
      text.strip.presence
    end
    
    def extract_letterboxd_uri(item)
      # Extract film slug from URL
      # Format: https://letterboxd.com/username/film/movie-slug/
      if item.link =~ %r{/film/([^/]+)/?}
        $1
      end
    end
    
    # Optional: Store last sync position for incremental syncs
    def store_sync_position(items)
      return if items.empty?
      
      newest_item = items.first
      sync_status.metadata['last_entry_guid'] = newest_item.guid
      sync_status.metadata['last_entry_date'] = newest_item.pubDate.iso8601
      sync_status.save!
    end
  end
end
