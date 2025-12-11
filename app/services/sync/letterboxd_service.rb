# app/services/sync/letterboxd_service.rb

require 'feedjira'
require 'open-uri'
require 'nokogiri'

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
      
      # Store the raw XML for custom parsing
      @raw_xml = URI.open(rss_url).read
      
      # Parse feed with Feedjira for basic structure
      feed = Feedjira.parse(@raw_xml)
      
      # Store feed metadata
      sync_status.update!(
        metadata: sync_status.metadata.merge(
          rss_url: rss_url,
          feed_title: feed.title,
          feed_description: feed.description,
          last_build_date: feed.last_built || feed.last_modified,
          feed_url: feed.url,
          etag: feed.etag
        )
      )
      
      # Parse the raw XML to get custom fields
      @xml_doc = Nokogiri::XML(@raw_xml)
      
      feed.entries
    end

    def process_item(entry)
      # Skip non-film entries (lists, articles, etc.)
      unless film_entry?(entry)
        log(:info, "Skipping non-film entry", 
          title: entry.title,
          url: entry.url,
          entry_type: detect_entry_type(entry)
        )
        return :skipped
      end
      
      # Parse the RSS entry with custom field extraction
      movie_data = parse_letterboxd_entry(entry)
      
      # Skip entries without a watched date (reviews without viewings)
      unless movie_data[:viewed_on]
        log(:info, "Skipping review without viewing date", 
          title: movie_data[:title],
          url: entry.url
        )
        return :skipped
      end
      
      # Find or create movie
      movie = Movie.find_or_create_by(
        title: movie_data[:title],
        year: movie_data[:year]
      ) do |m|
        m.letterboxd_id = movie_data[:letterboxd_id]
        m.url = movie_data[:film_url]
        m.tmdb_id = movie_data[:tmdb_id] if movie_data[:tmdb_id]
        log(:info, "Creating new movie", 
          title: m.title, 
          year: m.year,
          tmdb_id: m.tmdb_id
        )
      end
      
      # Update TMDB ID if we have it and it's missing
      if movie_data[:tmdb_id] && movie.tmdb_id.blank?
        movie.update!(tmdb_id: movie_data[:tmdb_id])
        log(:info, "Added TMDB ID to movie", 
          movie: movie.title, 
          tmdb_id: movie_data[:tmdb_id]
        )
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
      
      # Handle movie poster
      if movie_data[:poster_url].present?
        create_or_update_poster(movie, movie_data[:poster_url])
      end

      # Create or update viewing
      viewing = Viewing.find_or_initialize_by(
        movie: movie,
        viewed_on: movie_data[:viewed_on]
      )
      
      if viewing.new_record?
        viewing.assign_attributes(
          notes: movie_data[:review],
          rewatch: movie_data[:rewatch]
        )
        viewing.save!
        
        log(:success, "Created viewing", 
          movie: movie.title,
          rating: movie_data[:rating],
          viewed_on: movie_data[:viewed_on],
          rewatch: movie_data[:rewatch]
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
      if film_entry?(entry)
        entry.title.split(' - ').first || entry.title
      else
        "#{detect_entry_type(entry).capitalize}: #{entry.title}"
      end
    end

    private

    def parse_letterboxd_entry(entry)
      # Find the corresponding item in the XML document by matching the guid
      item_node = @xml_doc.xpath("//item[guid[text()='#{entry.entry_id}']]").first

      # Extract custom fields from the XML node
      custom_data = if item_node
        {
          watched_date: item_node.xpath("letterboxd:watchedDate", 
            'letterboxd' => 'https://letterboxd.com').text.presence,
          film_title: item_node.xpath("letterboxd:filmTitle", 
            'letterboxd' => 'https://letterboxd.com').text.presence,
          film_year: item_node.xpath("letterboxd:filmYear", 
            'letterboxd' => 'https://letterboxd.com').text.presence,
          member_rating: item_node.xpath("letterboxd:memberRating", 
            'letterboxd' => 'https://letterboxd.com').text.presence,
          rewatch: item_node.xpath("letterboxd:rewatch", 
            'letterboxd' => 'https://letterboxd.com').text.presence,
          tmdb_id: item_node.xpath("tmdb:movieId", 
            'tmdb' => 'https://themoviedb.org').text.presence
        }
      else
        {}
      end
      
      parsed_data = {
        title: custom_data[:film_title] || parse_title_from_text(entry.title),
        year: custom_data[:film_year]&.to_i || parse_year_from_text(entry.title),
        rating: parse_rating_value(custom_data[:member_rating]) || parse_rating_from_text(entry.title),
        viewed_on: parse_watched_date(custom_data[:watched_date]) || entry.published&.to_date,
        review: parse_review(entry.summary || entry.content),
        rewatch: custom_data[:rewatch] == 'Yes',
        letterboxd_id: extract_letterboxd_id(entry),
        film_url: extract_film_url(entry),
        tmdb_id: custom_data[:tmdb_id]
      }

      # Extract poster URL from content
      parsed_data[:poster_url] = extract_poster_url(entry)
      
      parsed_data
    end
    
    def parse_title_from_text(text)
      title_match = text.match(/^(.+?),\s*\d{4}/)
      title_match ? title_match[1] : text.split(' - ').first
    end
    
    def parse_year_from_text(text)
      year_match = text.match(/,\s*(\d{4})/)
      year_match ? year_match[1].to_i : nil
    end
    
    def parse_rating_from_text(text)
      stars = text.scan('★').count
      half_star = text.include?('½')
      
      return nil if stars == 0 && !half_star
      
      rating = stars.to_f
      rating += 0.5 if half_star
      rating
    end
    
    def parse_rating_value(rating_str)
      return nil if rating_str.blank?
      rating_str.to_f
    end
    
    def parse_watched_date(date_str)
      return nil if date_str.blank?
      Date.parse(date_str)
    rescue ArgumentError
      nil
    end
    
    def parse_review(content)
      return nil if content.blank?
      
      # Remove HTML tags and clean up
      text = ActionView::Base.full_sanitizer.sanitize(content)
      
      # Remove the "Watched on..." line if present
      text = text.gsub(/Watched on .+\.\s*/, '')
      
      text.strip.presence
    end
    
    def extract_letterboxd_id(entry)
      # Extract film slug from URL
      if entry.url =~ %r{/film/([^/]+)/?}
        $1.split('/').first
      end
    end
    
    def extract_film_url(entry)
      # Get the canonical film URL (without viewing number)
      if entry.url =~ %r{(https://letterboxd\.com/\w+/film/[^/]+)/?}
        $1 + '/'
      else
        entry.url
      end
    end
    
    def extract_poster_url(entry)
      content = entry.summary || entry.content
      return nil if content.blank?
      
      # Look for Letterboxd CDN image URLs
      if content =~ /https?:\/\/[as]\.ltrbxd\.com\/[^"'\s>]+/
        return $&
      end
      
      # Fallback: try to find any img src
      if content =~ /<img[^>]+src=["']([^"']+)["']/
        url = $1
        return url if url.include?('ltrbxd.com') || url.include?('film-poster')
      end
      
      nil
    end
    
    def film_entry?(entry)
      # Film entries have /film/ in the URL and not /list/ or /journal/
      entry.url.include?('/film/') && entry.url !~ /\/(list|journal)\//
    end
    
    def detect_entry_type(entry)
      case entry.url
      when /\/list\//
        'list'
      when /\/journal\//
        'journal'
      when /\/film\//
        'film'
      else
        'unknown'
      end
    end
    
    def create_or_update_poster(movie, poster_url)
      poster = movie.movie_posters.find_or_initialize_by(url: poster_url)
      
      if poster.new_record?
        poster.source = 'letterboxd'
        poster.primary = movie.movie_posters.empty?
        poster.save!
        
        log(:info, "Added poster for movie", 
          movie: movie.title,
          url: poster_url
        )
      end
    end
  end
end